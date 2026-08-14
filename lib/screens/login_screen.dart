import 'package:flutter/material.dart';

import '../data/account_repository.dart';
import '../models/user_account.dart';
import '../theme/app_colors.dart';
import 'account_setup_screen.dart';

/// Every-launch local login gate.
///
/// Existing accounts are shown as friendly emoji chips. Tapping one does
/// not enter immediately: it opens a password prompt, verifies the local
/// hash via [AccountRepository], then hands the unlocked [UserAccount] to
/// the app shell through [onLogin].
class LoginScreen extends StatefulWidget {
  final AccountRepository accountRepository;
  final List<String> availableSubjects;
  final ValueChanged<UserAccount> onLogin;

  const LoginScreen({
    super.key,
    required this.accountRepository,
    required this.availableSubjects,
    required this.onLogin,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late Future<List<UserAccount>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    _accountsFuture = widget.accountRepository.loadAccountsWithDemoDefaults();
  }

  Future<void> _refreshAccounts() async {
    setState(() {
      _accountsFuture = widget.accountRepository.loadAccountsWithDemoDefaults();
    });
  }

  Future<void> _createAccount() async {
    final account = await Navigator.of(context).push<UserAccount>(
      MaterialPageRoute(
        builder:
            (_) => AccountSetupScreen(
              accountRepository: widget.accountRepository,
              availableSubjects: widget.availableSubjects,
            ),
      ),
    );
    if (account == null || !mounted) return;
    await _refreshAccounts();
    widget.onLogin(account);
  }

  Future<void> _promptForPassword(UserAccount account) async {
    final unlocked = await showDialog<bool>(
      context: context,
      builder: (_) => _PasswordDialog(
        account: account,
        verifyPassword: widget.accountRepository.verifyPassword,
        resetPassword: widget.accountRepository.resetPassword,
      ),
    );
    if (unlocked != true || !mounted) return;
    // Re-fetch rather than logging in with the chip's copy — the subject
    // list may have been edited in Settings while this dialog was open,
    // and the shell should receive the freshest account.
    final latest = await widget.accountRepository.findAccount(account.username);
    if (!mounted || latest == null) return;
    widget.onLogin(latest);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'VCE Unpacked',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose your profile, then enter your password.',
                    style: TextStyle(fontSize: 14, color: context.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  FutureBuilder<List<UserAccount>>(
                    future: _accountsFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return CircularProgressIndicator(
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF007AFF),
                          ),
                          backgroundColor: context.statsBg,
                        );
                      }
                      final accounts = snapshot.data!;
                      return Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          for (final account in accounts)
                            _AccountChip(
                              account: account,
                              onTap: () => _promptForPassword(account),
                            ),
                          _CreateAccountChip(onTap: _createAccount),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Demo passwords: Demo Student = demo123, Demo Friend = friend123',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: context.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  final UserAccount account;
  final VoidCallback onTap;

  const _AccountChip({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Log in as ${account.username}',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.borderStrong, width: 0.6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(account.icon, style: const TextStyle(fontSize: 42)),
              const SizedBox(height: 10),
              Text(
                account.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${account.subjects.length} subject${account.subjects.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateAccountChip extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateAccountChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Create account',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.statsBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.border, width: 0.6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, size: 42, color: context.textPrimary),
              const SizedBox(height: 10),
              Text(
                'Create account',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pick subjects',
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal password prompt shown when a user taps their account chip.
///
/// This owns its [TextEditingController] (and the inline error state) so the
/// controller lives exactly as long as the dialog widget. Disposing it from
/// the caller immediately after `showDialog` returns is a bug: the route is
/// still animating out, and the autofocused [TextField] in that exit frame
/// would touch a controller that's already been disposed.
class _PasswordDialog extends StatefulWidget {
  final UserAccount account;
  final Future<bool> Function(String username, String password) verifyPassword;
  final Future<UserAccount> Function(String username, String newPassword)
  resetPassword;

  const _PasswordDialog({
    required this.account,
    required this.verifyPassword,
    required this.resetPassword,
  });

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _passwordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _error;
  bool _submitting = false;
  // No identity check on top of it: this is a single-user local device app
  // (see AccountRepository's doc comment), not a real auth boundary — a
  // reset just needs to replace the stored hash, not prove who's typing.
  bool _resetMode = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final ok = await widget.verifyPassword(
      widget.account.username,
      _passwordController.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _error = 'Wrong password. Try again.';
      });
    }
  }

  Future<void> _submitReset() async {
    if (_submitting) return;
    // Same existence/range/type policy account creation uses — see
    // AccountRepository.passwordError — so a reset can't set a password
    // account creation would have rejected.
    final passwordError = AccountRepository.passwordError(
      _newPasswordController.text,
    );
    if (passwordError != null) {
      setState(() => _error = passwordError);
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _error = "Passwords don't match.");
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    await widget.resetPassword(
      widget.account.username,
      _newPasswordController.text,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.cardBg,
      title: Row(
        children: [
          Text(widget.account.icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.account.username,
              style: TextStyle(color: context.textPrimary),
            ),
          ),
        ],
      ),
      content: _resetMode ? _buildResetContent() : _buildLoginContent(),
      actions: _resetMode ? _buildResetActions() : _buildLoginActions(),
    );
  }

  Widget _buildLoginContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _passwordController,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submit(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() {
              _resetMode = true;
              _error = null;
            }),
            child: const Text('Forgot password?'),
          ),
        ),
      ],
    );
  }

  Widget _buildResetContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _newPasswordController,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Confirm new password',
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submitReset(),
        ),
      ],
    );
  }

  List<Widget> _buildLoginActions() {
    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submitting ? null : _submit,
        child: const Text('Log in'),
      ),
    ];
  }

  List<Widget> _buildResetActions() {
    return [
      TextButton(
        onPressed: () => setState(() {
          _resetMode = false;
          _error = null;
        }),
        child: const Text('Back'),
      ),
      FilledButton(
        onPressed: _submitting ? null : _submitReset,
        child: const Text('Reset & log in'),
      ),
    ];
  }
}
