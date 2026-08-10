import 'package:flutter/material.dart';
import '../logic/study_grouping.dart';
import '../models/study_item.dart';
import '../theme/app_colors.dart';
import '../theme/category_colors.dart';

/// Displays [items] grouped under Unit / Area of Study headers, in the
/// order the backend pipeline emitted them (Unit 1 -> its Areas of
/// Study -> each Outcome and its Key Knowledge/Key Skill points, then
/// Unit 2, ...). Items with no unit (Command Term glossary entries)
/// are grouped under a trailing "Glossary" header instead.
///
/// A flat, ungrouped list works fine for a handful of hand-written
/// sample items, but a real subject can have 100+ extracted items —
/// without this grouping a student sees one undifferentiated scroll
/// with no sense of which unit/outcome they're looking at.
class ResultsList extends StatelessWidget {
  final List<StudyItem> items;
  final StudyItem? selectedItem;
  final ValueChanged<StudyItem> onItemSelected;
  final int generation;
  final String emptyMessage;

  const ResultsList({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.onItemSelected,
    required this.generation,
    required this.emptyMessage,
  });

  /// Groups [items] into header/item rows up front (see
  /// [buildRows]) — cheap string comparisons over `items`, unlike
  /// constructing an `_ItemCard`'s widget tree — so `ListView.builder`
  /// below builds only the rows actually near the viewport instead of
  /// eagerly building every card: for an 800+ item subject (e.g.
  /// Mathematics) that's the difference between constructing a handful
  /// of widgets and constructing all of them before the first frame.
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(fontSize: 13, color: context.textSecondary),
        ),
      );
    }

    final rows = buildRows(items);

    return ListView.builder(
      key: ValueKey(generation),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return switch (row) {
          StudyHeaderRow(:final text, :final isSubHeader) =>
            isSubHeader ? _SubGroupHeader(text) : _GroupHeader(text),
          StudyItemRow(:final item) => _ItemCard(
            item: item,
            isSelected: item.id == selectedItem?.id,
            onTap: () => onItemSelected(item),
          ),
        };
      },
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String text;
  const _GroupHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: context.textPrimary,
        ),
      ),
    );
  }
}

class _SubGroupHeader extends StatelessWidget {
  final String text;
  const _SubGroupHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF007AFF),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// A result card row: category-colored left stripe, a headline (the
/// item's real title when it has one, else the derived short headline —
/// see [cardHeadline] in lib/logic/study_grouping.dart, shared with the
/// unit tests), a plain-language preview, and a "Completed" checkmark
/// for marked-done items.
class _ItemCard extends StatefulWidget {
  final StudyItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _ItemCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  bool _pressed = false;

  // Outcome and Command Term items have a genuinely meaningful title
  // ("Outcome 1", "Analyse") — Key Knowledge/Key Skill points don't
  // (their "title" is just the first few words of a sentence), so for
  // those we lead with the plain-language preview instead of a fake
  // bolded headline.
  bool get _hasRealTitle =>
      widget.item.category == 'Outcome' ||
      widget.item.category == 'Command Term';

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSelected = widget.isSelected;
    final accent = categoryColor(item.category);
    final neutral = isSelected ? context.borderStrong : context.border;
    final neutralWidth = isSelected ? 1.0 : 0.5;
    return GestureDetector(
      onTap: widget.onTap,
      // Press feedback: every pressable element should feel like it
      // heard the tap. Kept short (120ms) and transform-only so it
      // stays cheap even when scrolling through a long results list.
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          // Flutter can't paint a BorderRadius on a Border with
          // per-side colors — a Stack + ClipRRect gives the same
          // rounded-corner-with-a-colored-edge look without that
          // restriction: the accent stripe is a plain colored Container
          // clipped to the same rounded rect as the card underneath it.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
                  decoration: BoxDecoration(
                    color: isSelected ? context.statsBg : context.cardBg,
                    border: Border.all(color: neutral, width: neutralWidth),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _hasRealTitle ? item.title : cardHeadline(item),
                              maxLines: _hasRealTitle ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    _hasRealTitle
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                color: context.textPrimary,
                                height: 1.35,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.category,
                              style: TextStyle(
                                fontSize: 10,
                                color: accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_hasRealTitle) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.plainLanguageText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (item.isCompleted) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 12,
                              color: Color(0xFF34C759),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Completed',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF34C759),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Category-colored left stripe, clipped to the same
                // rounded rect as the card via the ClipRRect above.
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 3, color: accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
