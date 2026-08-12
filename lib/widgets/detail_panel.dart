import 'package:flutter/material.dart';
import '../models/study_item.dart';
import '../theme/app_colors.dart';
import '../theme/category_colors.dart';

class DetailPanel extends StatelessWidget {
  final StudyItem? item;
  final ValueChanged<bool> onCompletionChanged;

  const DetailPanel({
    super.key,
    required this.item,
    required this.onCompletionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: context.cardBg),
      // Crossfades between items (and the empty state) instead of a hard
      // cut — one tap = one transition, an occasional action where a
      // transition helps orient the reader rather than a frequent one
      // that would just slow things down. Keyed by item id so switching
      // between two items also transitions, not just null <-> non-null.
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder:
            (child, animation) =>
                FadeTransition(opacity: animation, child: child),
        child:
            item == null
                ? _EmptyState(key: const ValueKey('empty'))
                : _ItemDetail(
                  key: ValueKey(item!.id),
                  item: item!,
                  onCompletionChanged: onCompletionChanged,
                ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Select a study item to view details',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: context.textSecondary),
        ),
      ),
    );
  }
}

class _ItemDetail extends StatelessWidget {
  final StudyItem item;
  final ValueChanged<bool> onCompletionChanged;

  const _ItemDetail({
    super.key,
    required this.item,
    required this.onCompletionChanged,
  });

  bool get _hasRealTitle =>
      item.category == 'Outcome' || item.category == 'Command Term';

  @override
  Widget build(BuildContext context) {
    final studyItem = item;
    final accent = categoryColor(studyItem.category);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (studyItem.unit != null || studyItem.areaOfStudy != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                [
                  if (studyItem.unit != null) studyItem.unit!,
                  if (studyItem.areaOfStudy != null) studyItem.areaOfStudy!,
                  if (studyItem.outcome != null) studyItem.outcome!,
                ].join(' > '),
                style: TextStyle(
                  fontSize: 11,
                  color: const Color(0xFF007AFF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _hasRealTitle ? studyItem.title : studyItem.category,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  studyItem.category,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            studyItem.subject,
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
          const SizedBox(height: 20),
          Text(
            'Official Text',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.surfaceBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.border, width: 0.5),
            ),
            child: _FormattedText(
              text: studyItem.officialText,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Plain Language',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF34C759),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.successBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF34C759).withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child:
                studyItem.plainLanguageText.trim() ==
                        studyItem.officialText.trim()
                    // The backend's simplifier trims prose and swaps
                    // known jargon/phrases — for content that's already
                    // plain (no jargon, already short), there's nothing
                    // to change. Saying so explicitly here reads as an
                    // honest "nothing to fix" rather than a duplicate
                    // that looks like the feature silently failed.
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: Color(0xFF34C759),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This is already written in plain language — nothing needed simplifying.',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textPrimary,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    )
                    : _FormattedText(
                      text: studyItem.plainLanguageText,
                      color: context.textPrimary,
                    ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                height: 32,
                child: ElevatedButton.icon(
                  onPressed: () => onCompletionChanged(!studyItem.isCompleted),
                  // A short crossfade on the icon/label swap gives the
                  // toggle a clear "state changed" signal instead of an
                  // instant jump — one tap = one transition.
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      studyItem.isCompleted
                          ? Icons.undo
                          : Icons.check_circle_outline,
                      size: 16,
                      key: ValueKey(studyItem.isCompleted),
                    ),
                  ),
                  label: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Text(
                      studyItem.isCompleted
                          ? 'Mark Incomplete'
                          : 'Mark Complete',
                      style: const TextStyle(fontSize: 12),
                      key: ValueKey(studyItem.isCompleted),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        studyItem.isCompleted
                            ? context.statsBg
                            : const Color(0xFF007AFF),
                    foregroundColor:
                        studyItem.isCompleted
                            ? context.textPrimary
                            : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side:
                          studyItem.isCompleted
                              ? BorderSide(
                                color: context.borderStrong,
                                width: 0.5,
                              )
                              : BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Renders official/plain-language text as a proper bullet list when
/// it's really a semicolon-joined list of dot points (produced when the
/// backend pipeline folds nested sub-bullets into their parent item),
/// instead of showing the raw "...such as:; tables; queries;..." string
/// as one dense run-on line with visible semicolons.
class _FormattedText extends StatelessWidget {
  final String text;
  final Color color;

  const _FormattedText({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(fontSize: 13, color: color, height: 1.6);

    if (!text.contains('; ')) {
      return Text(text, style: baseStyle);
    }

    final segments =
        text
            .split(';')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
    // The first segment is normally the list's lead-in ("structural
    // characteristics of RDBMS, such as:") — show it as an intro line
    // above the bullets rather than as the first bullet itself.
    final intro = segments.first;
    final bullets =
        segments.length > 1 ? segments.sublist(1) : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(intro, style: baseStyle),
        if (bullets.isNotEmpty) const SizedBox(height: 6),
        for (final bullet in bullets)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: baseStyle),
                Expanded(child: Text(bullet, style: baseStyle)),
              ],
            ),
          ),
      ],
    );
  }
}
