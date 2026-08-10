import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Left-hand subject selector: a fixed-width (220 px) vertical list, one
/// row per subject, with the active subject highlighted by an inset
/// accent capsule. Purely presentational — the parent owns which subject
/// is selected and what happens on tap.
class Sidebar extends StatelessWidget {
  final List<String> subjects;
  final String? selectedSubject;
  final ValueChanged<String> onSubjectSelected;

  const Sidebar({
    super.key,
    required this.subjects,
    required this.selectedSubject,
    required this.onSubjectSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Container(
        decoration: BoxDecoration(
          color: context.cardBg,
          border: Border(right: BorderSide(color: context.border, width: 0.5)),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          itemCount: subjects.length,
          itemBuilder: (context, index) {
            final subject = subjects[index];
            final isSelected = subject == selectedSubject;
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Semantics(
                button: true,
                selected: isSelected,
                label: 'Subject: $subject',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onSubjectSelected(subject),
                  // macOS sidebars (Finder, Mail, System Settings) mark
                  // the active row with a solid accent-tinted capsule
                  // inset from the edges, not a full-bleed highlight or
                  // a border stripe — that's the specific detail that
                  // reads as "native Mac" rather than a generic list.
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? const Color(0xFF007AFF).withValues(alpha: 0.14)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color:
                            isSelected
                                ? const Color(0xFF007AFF)
                                : context.textSecondary,
                      ),
                      child: Text(subject),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
