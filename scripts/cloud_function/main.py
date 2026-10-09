"""Tracely voice-parse proxy.

Flutter never talks to Dialogflow directly — the service account key that
can query it must never ship inside the app (same reason the Wit.ai
server token couldn't: either would get pulled straight out of the APK).
This function sits between them: runs under its own service account (no
key file needed at runtime — Application Default Credentials picks up the
identity the function was deployed with), so the only thing exposed to
the app is this URL, no credentials at all.

Deploy as a 2nd gen HTTP Cloud Function, entry point detect_voice_intent,
runtime service account = tracely-voice-trainer@<project>.iam.gserviceaccount.com
(already has the Dialogflow role from scripts/train_dialogflow.py's setup —
reusing it here means no new IAM grant needed).
"""
import uuid

import functions_framework
import google.auth
from flask import jsonify
from google.cloud import dialogflow_v2 as df

_CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
}


@functions_framework.http
def detect_voice_intent(request):
    if request.method == "OPTIONS":
        return ("", 204, _CORS_HEADERS)

    data = request.get_json(silent=True) or {}
    text = (data.get("text") or "").strip()
    if not text:
        return (jsonify({"error": "missing text"}), 400, _CORS_HEADERS)

    _, project_id = google.auth.default()
    session_client = df.SessionsClient()
    session = session_client.session_path(project_id, str(uuid.uuid4()))
    query_input = df.QueryInput(text=df.TextInput(text=text, language_code="en"))

    try:
        response = session_client.detect_intent(session=session, query_input=query_input)
    except Exception as e:  # noqa: BLE001 — surfaced to the app as a parse failure, not a crash
        return (jsonify({"error": str(e)}), 502, _CORS_HEADERS)

    qr = response.query_result
    return (
        jsonify(
            {
                "text": qr.query_text,
                "intent": qr.intent.display_name,
                "confidence": qr.intent_detection_confidence,
                "parameters": dict(qr.parameters),
            }
        ),
        200,
        _CORS_HEADERS,
    )
