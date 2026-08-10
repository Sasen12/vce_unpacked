import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_colors.dart';
import '../theme/theme_model.dart';

/// Right-edge slide-out panel with the app's settings (the dark-mode
/// switch) and the version/about footer. Opened via the static
/// [SettingsSlideout.show], which animates it in from the right edge
/// over a dimmed, tappable-to-dismiss barrier.
class SettingsSlideout extends StatefulWidget {
  final ThemeModel themeModel;

  const SettingsSlideout({super.key, required this.themeModel});

  static void show(BuildContext context, ThemeModel themeModel) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Settings',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder:
          (ctx, anim, _) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: SettingsSlideout(themeModel: themeModel),
            ),
          ),
      transitionBuilder: (ctx, anim, _, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );
  }

  @override
  State<SettingsSlideout> createState() => _SettingsSlideoutState();
}

class _SettingsSlideoutState extends State<SettingsSlideout> {
  String? _version;

  @override
  void initState() {
    super.initState();
    widget.themeModel.addListener(_onThemeChanged);
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    String? version;
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
    } catch (_) {
      // Platform channel unavailable (e.g. widget tests) — keep null.
    }
    if (!mounted) return;
    setState(() => _version = version);
  }

  @override
  void dispose() {
    widget.themeModel.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 16,
      color: context.cardBg,
      child: SizedBox(
        width: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.border, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: context.statsBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dark Mode',
                    style: TextStyle(fontSize: 15, color: context.textPrimary),
                  ),
                  Switch(
                    value: widget.themeModel.isDark,
                    onChanged: (_) => widget.themeModel.toggleTheme(),
                    activeColor: const Color(0xFF007AFF),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: context.border, width: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VCE Unpacked v${_version ?? '…'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'A study tool for VCE subjects.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
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
