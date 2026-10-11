import 'package:flutter/material.dart';

/// A single selectable reason card within a category.
class ReasonItem {
  const ReasonItem({required this.label, required this.key});
  final String label;
  final String key;
}

/// A top-level reason category.
class ReasonCategory {
  const ReasonCategory({
    required this.key,
    required this.icon,
    required this.label,
    required this.reasons,
  });
  final String key;
  final IconData icon;
  final String label;
  final List<ReasonItem> reasons;
}

/// Follow-up question definition.
class FollowUpQuestion {
  const FollowUpQuestion({
    required this.question,
    required this.options,
  });
  final String question;
  final List<String> options;
}

/// Result of resolving follow-up questions from a list of selected reason keys.
class ResolvedFollowUp {
  const ResolvedFollowUp({
    required this.triggerReasonKey,
    required this.followUp,
  });
  final String triggerReasonKey;
  final FollowUpQuestion followUp;
}

/// The 5 reason categories with their 21 reasons (exact order and keys).
const kReflectionCategories = <ReasonCategory>[
  ReasonCategory(
    key: 'energy',
    icon: Icons.bedtime_outlined,
    label: 'Energy',
    reasons: [
      ReasonItem(label: 'Low Energy', key: 'low_energy'),
      ReasonItem(label: 'Poor Sleep', key: 'poor_sleep'),
      ReasonItem(label: 'Felt Sick', key: 'felt_sick'),
      ReasonItem(label: 'Burned Out', key: 'burned_out'),
    ],
  ),
  ReasonCategory(
    key: 'time',
    icon: Icons.schedule_outlined,
    label: 'Time',
    reasons: [
      ReasonItem(label: 'Too Busy', key: 'too_busy'),
      ReasonItem(label: 'Unexpected Work', key: 'unexpected_work'),
      ReasonItem(label: 'Meetings', key: 'meetings'),
      ReasonItem(label: 'Family', key: 'family'),
    ],
  ),
  ReasonCategory(
    key: 'mind',
    icon: Icons.psychology_outlined,
    label: 'Mind',
    reasons: [
      ReasonItem(label: 'Lost Motivation', key: 'lost_motivation'),
      ReasonItem(label: 'Procrastinated', key: 'procrastinated'),
      ReasonItem(label: 'Forgot', key: 'forgot'),
      ReasonItem(label: 'Overwhelmed', key: 'felt_overwhelmed'),
      ReasonItem(label: "Couldn't Focus", key: 'couldnt_focus'),
    ],
  ),
  ReasonCategory(
    key: 'environment',
    icon: Icons.pin_drop_outlined,
    label: 'Environment',
    reasons: [
      ReasonItem(label: 'Traveling', key: 'traveling'),
      ReasonItem(label: 'Weather', key: 'weather'),
      ReasonItem(label: 'No Equipment', key: 'no_equipment'),
      ReasonItem(label: 'Away From Home', key: 'outside_home'),
    ],
  ),
  ReasonCategory(
    key: 'personal',
    icon: Icons.self_improvement_outlined,
    label: 'Personal',
    reasons: [
      ReasonItem(label: 'Needed Rest', key: 'needed_rest'),
      ReasonItem(label: 'Mental Break', key: 'mental_break'),
      ReasonItem(label: 'Personal Event', key: 'personal_event'),
      ReasonItem(label: 'Emergency', key: 'emergency'),
    ],
  ),
];

/// Follow-up question lookup by triggering reason key.
const kFollowUpMap = <String, FollowUpQuestion>{
  'low_energy': FollowUpQuestion(
    question: 'How was your energy?',
    options: ['Great', 'Okay', 'Very Low'],
  ),
  'poor_sleep': FollowUpQuestion(
    question: 'How did you sleep?',
    options: ['Badly', 'Okay', 'Well'],
  ),
  'too_busy': FollowUpQuestion(
    question: 'What kept you busy?',
    options: ['Work', 'College', 'Family', 'Other'],
  ),
  'lost_motivation': FollowUpQuestion(
    question: 'Has this been going on?',
    options: ['Just today', 'A few days', 'A while'],
  ),
  'felt_overwhelmed': FollowUpQuestion(
    question: 'Was it habit-related?',
    options: ['Yes', 'No', 'Not sure'],
  ),
};

/// Returns the triggering reason key and follow-up question for the first
/// matching trigger key in [selectedKeys], or null if none trigger a follow-up.
ResolvedFollowUp? resolveFollowUp(List<String> selectedKeys) {
  for (final key in selectedKeys) {
    final followUp = kFollowUpMap[key];
    if (followUp != null) {
      return ResolvedFollowUp(triggerReasonKey: key, followUp: followUp);
    }
  }
  return null;
}

/// Finds the human-readable label for [reasonKey].
String findReasonLabel(String reasonKey) {
  for (final category in kReflectionCategories) {
    for (final reason in category.reasons) {
      if (reason.key == reasonKey) return reason.label;
    }
  }
  return reasonKey;
}
