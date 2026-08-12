import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/user_account.dart';
import '../theme/app_colors.dart';
import '../theme/theme_model.dart';

/// Right-edge slide-out panel with the app's settings: the active user,
/// subject editing + log out, the dark-mode switch, and the version/about
/// footer. Opened via the static [SettingsSlideout.show], which animates
/// it in from the right edge over a dimmed, tappable-to-dismiss barrier.
class SettingsSlideout extends StatefulWidget {
  final ThemeModel themeModel;
  final UserAccount account;

  // Handed up from HomeScreen (which got them from AuthGate): reopening the
  // subject picker and returning to the login screen both require shell
  // state, so the slideout just forwards the taps.
  final VoidCallback? onLogout;
  final VoidCallback? onEditSubjects;

  const SettingsSlideout({
    super.key,
    required this.themeModel,
    required this.account,
    this.onLogout,
    this.onEditSubjects,
  });

  static void show(
    BuildContext context,
    ThemeModel themeModel, {
    required UserAccount account,
    VoidCallback? onLogout,
    VoidCallback? onEditSubjects,
  }) {
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
              child: SettingsSlideout(
                themeModel: themeModel,
                account: account,
                onLogout: onLogout,
                onEditSubjects: onEditSubjects,
              ),
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
            // Active user: emoji avatar + name + subject count.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.statsBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.borderStrong,
                        width: 0.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        widget.account.icon,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.account.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.account.subjects.length} subject${widget.account.subjects.length == 1 ? '' : 's'}',
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
            const SizedBox(height: 4),
            _SettingsEntry(
              icon: Icons.subject,
              label: 'My subjects',
              onTap: widget.onEditSubjects,
            ),
            _SettingsEntry(
              icon: Icons.logout,
              label: 'Log out',
              onTap: widget.onLogout,
            ),
            Divider(height: 1, color: context.border),
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
                    // activeColor was renamed to activeThumbColor in newer
                    // Flutter, but it isn't available on the pinned local
                    // SDK — ignore the deprecation so analyze is clean on
                    // both the local 3.29 toolchain and CI's 3.44.
                    // ignore: deprecated_member_use
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

/// One tappable action row inside the settings slideout. Tapping pops the
/// slideout first, then fires the callback so the target screen (subject
/// picker, login screen) opens cleanly on top of HomeScreen.
class _SettingsEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SettingsEntry({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              Navigator.of(context).pop();
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: context.textSecondary),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: context.textPrimary),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: context.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
