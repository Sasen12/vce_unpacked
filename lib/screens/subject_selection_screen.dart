import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Reusable multi-select checklist for choosing which VCE subjects to
/// include in the main app. At least one subject must be selected for the
/// "Done" button to be enabled — used both during account creation and for
/// the "My subjects" edit in Settings.
class SubjectSelectionScreen extends StatefulWidget {
  final List<String> availableSubjects;
  final List<String> initialSelection;

  const SubjectSelectionScreen({
    super.key,
    required this.availableSubjects,
    required this.initialSelection,
  });

  @override
  State<SubjectSelectionScreen> createState() => _SubjectSelectionScreenState();
}

class _SubjectSelectionScreenState extends State<SubjectSelectionScreen> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection.toSet();
  }

  @override
  Widget build(BuildContext context) {
    // Copy-then-sort so the caller's [availableSubjects] list is never
    // mutated — the same list is shared by account creation and Settings.
    final sortedSubjects = widget.availableSubjects.toList()..sort();

    return Scaffold(
      backgroundColor: context.surfaceBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              decoration: BoxDecoration(
                color: context.cardBg,
                border: Border(
                  bottom: BorderSide(color: context.border, width: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose your subjects',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pick at least one. You can change this later in Settings.',
                    style: TextStyle(fontSize: 14, color: context.textSecondary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                itemCount: sortedSubjects.length,
                separatorBuilder:
                    (_, __) => Divider(height: 1, color: context.border),
                itemBuilder: (context, index) {
                  final subject = sortedSubjects[index];
                  final isSelected = _selected.contains(subject);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selected.remove(subject);
                        } else {
                          _selected.add(subject);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? context.statsBg : context.cardBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF007AFF)
                                    : context.borderStrong,
                                width: 1.5,
                              ),
                              color: isSelected
                                  ? const Color(0xFF007AFF)
                                  : context.cardBg,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              subject,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardBg,
                border: Border(
                  top: BorderSide(color: context.border, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selected.isEmpty
                          ? 'Select at least one subject'
                          : '${_selected.length} subject${_selected.length == 1 ? '' : 's'} selected',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_selected.toList()),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
