import '../models/study_item.dart';

/// Pure in-memory filter over a list of [StudyItem]s.
///
/// Extracted out of `HomeScreen._applyFilters` so the three-axis AND
/// logic (subject, category, full-text search) can be unit-tested
/// without pumping the whole app. The dataset is 2,000+ items; keeping
/// this a standalone function means the exact same code path runs in
/// tests as in the app, and the widget layer stays a thin wrapper.
///
/// Returns only the [items] matching every supplied axis, in original
/// order:
///   1. Subject — skipped when [subject] is null.
///   2. Category — skipped when [category] is null or `'All'`.
///   3. Full-text search across title, official text and plain language —
///      skipped when [query] is empty. Deliberately NOT trimmed before
///      the emptiness check, so a whitespace-only query behaves exactly
///      as it did before extraction (matches anything containing a space).
List<StudyItem> filterItems(
  List<StudyItem> items, {
  String? subject,
  String? category,
  String query = '',
}) {
  return items.where((item) {
    if (subject != null && item.subject != subject) {
      return false;
    }
    if (category != null && category != 'All' && item.category != category) {
      return false;
    }
    if (query.isNotEmpty) {
      final q = query.trim().toLowerCase();
      // Whitespace-only queries match everything: the search axis is
      // skipped entirely, so an all-spaces string behaves like an empty
      // one (kept intentionally, to match the pre-extraction behaviour).
      if (q.isEmpty) return true;
      // Simple case-insensitive substring search — broad matches without
      // over-complication. The backend already normalizes text, so this is reliable.
      final titleMatch = item.title.toLowerCase().contains(q);
      final officialMatch = item.officialText.toLowerCase().contains(q);
      final plainMatch = item.plainLanguageText.toLowerCase().contains(q);
      if (!titleMatch && !officialMatch && !plainMatch) {
        return false;
      }
    }
    return true;
  }).toList();
}
