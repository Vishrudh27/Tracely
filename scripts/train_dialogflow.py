#!/usr/bin/env python3
"""One-shot trainer for the Tracely Dialogflow ES agent.

Replaces train_wit.py — Wit.ai's intent classifier is broken (confirmed
upstream bug, github.com/wit-ai/wit/issues/2817: entities resolve fine,
intents always return empty, unfixed for 6+ months). Same training data
(wit_training_data.py), same idea, different vendor.

Usage:
    python3 scripts/train_dialogflow.py /path/to/service-account.json

Requires the venv set up alongside this script:
    python3 -m venv scripts/.venv
    scripts/.venv/bin/pip install google-cloud-dialogflow

Creates the 4 entity types + 5 intents this app needs (skips ones that
already exist, by display name), each with all its training phrases from
wit_training_data.py. Dialogflow ES intents are created with ALL their
phrases in one call (no separate bulk-upload step like Wit's
POST /utterances) and training kicks off automatically — no manual
"Train and Validate" click needed, unlike Wit.ai.
"""
from __future__ import annotations

import sys

from google.cloud import dialogflow_v2 as df
from google.oauth2 import service_account

from wit_training_data import TRAINING_DATA

# Dialogflow entity types are built fresh per intent group below so the
# role names line up 1:1 with the Wit.ai ones already used elsewhere
# (habit_name, task_name, time_phrase, reason) — same training data,
# same entity names, just a different vendor's wire format.
ENTITY_TYPES = ["habit_name", "task_name", "time_phrase", "reason"]


def load_credentials(key_path: str):
    creds = service_account.Credentials.from_service_account_file(key_path)
    project_id = creds.project_id
    return creds, project_id


def ensure_entity_type(client: df.EntityTypesClient, parent: str, name: str) -> str:
    """Returns the entity type's resource name, creating it (as a
    free-text/system-ish kind via KIND_LIST with no fixed values list,
    i.e. KIND_MAP would need explicit entries) if missing.

    Dialogflow ES entity types need at least one entry to exist, but a
    KIND_LIST entity only ever matches its literal listed values/synonyms
    — it does NOT generalize to new text like Wit.ai's free-text lookup
    does. The actual free-text equivalent is KIND_MAP with
    auto_expansion_mode=AUTO_EXPANSION_MODE_DEFAULT: Dialogflow then
    extracts whatever text sits in that tagged training-phrase position,
    not just the seed value below.
    """
    for et in client.list_entity_types(parent=parent):
        if et.display_name == name:
            return et.name
    entity_type = df.EntityType(
        display_name=name,
        kind=df.EntityType.Kind.KIND_MAP,
        auto_expansion_mode=df.EntityType.AutoExpansionMode.AUTO_EXPANSION_MODE_DEFAULT,
        entities=[df.EntityType.Entity(value=name, synonyms=[name])],
    )
    created = client.create_entity_type(parent=parent, entity_type=entity_type)
    print(f"entity type {name}: created {created.name}")
    return created.name


def build_training_phrase(
    text: str, tags: list[tuple[str, str]]
) -> df.Intent.TrainingPhrase:
    """Splits `text` into plain / entity-annotated parts in order, same
    span logic as wit_train.py's build_entity_spans — left to right,
    no overlapping reuse of the same substring."""
    parts: list[df.Intent.TrainingPhrase.Part] = []
    cursor = 0
    spans: list[tuple[int, int, str, str]] = []  # start, end, role, body
    search_from = 0
    for role, substring in tags:
        idx = text.find(substring, search_from)
        if idx == -1:
            idx = text.find(substring)
        if idx == -1:
            raise ValueError(f"substring {substring!r} not found in {text!r}")
        end = idx + len(substring)
        spans.append((idx, end, role, substring))
        search_from = end
    spans.sort(key=lambda s: s[0])

    for start, end, role, body in spans:
        if start > cursor:
            parts.append(df.Intent.TrainingPhrase.Part(text=text[cursor:start]))
        parts.append(
            df.Intent.TrainingPhrase.Part(
                text=body,
                entity_type=f"@{role}",
                alias=role,
                user_defined=True,
            )
        )
        cursor = end
    if cursor < len(text):
        parts.append(df.Intent.TrainingPhrase.Part(text=text[cursor:]))

    return df.Intent.TrainingPhrase(type_=df.Intent.TrainingPhrase.Type.EXAMPLE, parts=parts)


def _phrase_text(tp: df.Intent.TrainingPhrase) -> str:
    return "".join(p.text for p in tp.parts)


def _build_parameters(roles: set[str]) -> list[df.Intent.Parameter]:
    """Without this, Dialogflow still tags entity spans inside training
    phrases but never surfaces them in detect_intent's query_result —
    they have to also be declared as output parameters."""
    return [
        df.Intent.Parameter(
            display_name=role,
            entity_type_display_name=f"@{role}",
            value=f"${role}",
            mandatory=False,
        )
        for role in sorted(roles)
    ]


def ensure_intent(
    client: df.IntentsClient,
    parent: str,
    name: str,
    phrases: list[df.Intent.TrainingPhrase],
    roles: set[str],
    existing_by_name: dict[str, df.Intent],
) -> None:
    parameters = _build_parameters(roles)
    existing = existing_by_name.get(name)
    if existing is not None:
        # existing_by_name was fetched with INTENT_VIEW_FULL, so
        # existing.training_phrases is already populated — the default
        # (non-FULL) list view returns it empty, and extending onto that
        # would silently wipe every phrase uploaded by a previous run.
        already = {_phrase_text(tp) for tp in existing.training_phrases}
        new_ones = [p for p in phrases if _phrase_text(p) not in already]
        existing.parameters.clear()
        existing.parameters.extend(parameters)
        if not new_ones:
            client.update_intent(intent=existing)
            print(f"intent {name}: already up to date ({len(already)} phrases)")
            return
        existing.training_phrases.extend(new_ones)
        client.update_intent(intent=existing)
        print(f"intent {name}: added {len(new_ones)} new phrases (had {len(already)})")
        return
    intent = df.Intent(display_name=name, training_phrases=phrases, parameters=parameters)
    created = client.create_intent(parent=parent, intent=intent)
    print(f"intent {name}: created {created.name} with {len(phrases)} phrases")


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("Usage: python3 scripts/train_dialogflow.py /path/to/service-account.json")
    key_path = sys.argv[1]
    creds, project_id = load_credentials(key_path)
    parent_project = f"projects/{project_id}/agent"

    entity_client = df.EntityTypesClient(credentials=creds)
    intent_client = df.IntentsClient(credentials=creds)

    print(f"-- ensuring {len(ENTITY_TYPES)} entity types --")
    for name in ENTITY_TYPES:
        ensure_entity_type(entity_client, parent_project, name)

    print("-- grouping training phrases by intent --")
    by_intent: dict[str, list[df.Intent.TrainingPhrase]] = {}
    roles_by_intent: dict[str, set[str]] = {}
    for text, intent_name, tags in TRAINING_DATA:
        by_intent.setdefault(intent_name, []).append(build_training_phrase(text, tags))
        roles_by_intent.setdefault(intent_name, set()).update(role for role, _ in tags)

    list_req = df.ListIntentsRequest(parent=parent_project, intent_view=df.IntentView.INTENT_VIEW_FULL)
    existing_by_name = {i.display_name: i for i in intent_client.list_intents(request=list_req)}

    print(f"-- ensuring {len(by_intent)} intents --")
    for intent_name, phrases in by_intent.items():
        ensure_intent(
            intent_client,
            parent_project,
            intent_name,
            phrases,
            roles_by_intent[intent_name],
            existing_by_name,
        )

    print(
        "done. Dialogflow ES trains automatically after intent create/update "
        "— usually ready within seconds, check the console's Try It Now box."
    )


if __name__ == "__main__":
    main()
