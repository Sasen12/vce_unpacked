import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The full-text search field above the results list.
///
/// The clear (✕) button's visibility is read straight from
/// [controller.text] at build time rather than kept in local state —
/// that only works because the parent screen rebuilds this widget on
/// every keystroke. When the parent supplies [onClear] it takes over
/// the button's action, so both the ✕ here and the footer's "Clear"
/// link cancel any pending debounce and re-filter immediately —
/// clearing is never subject to the typing debounce.
class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onClear,
  });

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
                        onPressed: onClear ?? () {
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
