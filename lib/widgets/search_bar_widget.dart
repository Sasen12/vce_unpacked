import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The full-text search field above the results list.
///
/// The clear (✕) button's visibility is read straight from
/// [controller.text] at build time rather than kept in local state —
/// that only works because the parent screen rebuilds this widget on
/// every keystroke. Clearing here also goes through the parent's
/// debounced path (a ~200ms wait before the filter actually re-runs),
/// unlike the footer's "Clear" link, which cancels the debounce and
/// applies immediately — two clears, two behaviours.
class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const SearchBarWidget({super.key, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Search across all content',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Search across all content…',
            hintStyle: TextStyle(fontSize: 13, color: context.textSecondary),
            prefixIcon: Icon(
              Icons.search,
              size: 16,
              color: context.textSecondary,
            ),
            filled: true,
            fillColor: context.surfaceBg,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            suffixIcon:
                controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          controller.clear();
                          onChanged('');
                        },
                        icon: Icon(
                          Icons.close,
                          size: 15,
                          color: context.textSecondary,
                        ),
                      ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          style: TextStyle(fontSize: 13, color: context.textPrimary),
        ),
      ),
    );
  }
}
