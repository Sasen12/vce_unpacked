import 'package:flutter/material.dart';

import '../data/account_repository.dart';
import '../models/user_account.dart';
import '../theme/app_colors.dart';
import 'subject_selection_screen.dart';

/// Account creation form: username + password + fun emoji picker, followed
/// by subject selection. On completion the new [UserAccount] is returned to
/// [LoginScreen] through [Navigator.pop].
class AccountSetupScreen extends StatefulWidget {
  final AccountRepository accountRepository;
  final List<String> availableSubjects;

  const AccountSetupScreen({
    super.key,
    required this.accountRepository,
    required this.availableSubjects,
  });

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  static const _emojiOptions = [
    '🦊',
    '🐱',
    '🐶',
    '🐼',
    '🦄',
    '🐸',
    '🐙',
    '🦉',
    '🐝',
    '🦋',
  ];

  // Type check: letters, numbers, spaces, apostrophes and hyphens only —
  // covers real names while rejecting stray symbols/emoji typed by mistake.
  static final _nameTypePattern = RegExp(r"^[A-Za-z0-9 '-]+$");
  static const _minNameLength = 2;
  static const _maxNameLength = 24;

  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedIcon = _emojiOptions.first;
  bool _obscurePassword = true;
  String? _nameError;
  String? _passwordError;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _nameError = null;
      _passwordError = null;
    });

    bool hasError = false;

    // Existence check.
    if (name.isEmpty) {
      setState(() => _nameError = 'Please enter a name.');
      hasError = true;
    }
    // Range check.
    else if (name.length < _minNameLength || name.length > _maxNameLength) {
      setState(
        () => _nameError =
            'Name must be $_minNameLength-$_maxNameLength characters.',
      );
      hasError = true;
    }
    // Type check.
    else if (!_nameTypePattern.hasMatch(name)) {
      setState(
        () => _nameError = 'Name can only contain letters, numbers, spaces, '
            "apostrophes and hyphens.",
      );
      hasError = true;
    } else if (await widget.accountRepository.findAccount(name) != null) {
      setState(() => _nameError = 'That name is already taken.');
      hasError = true;
    }

    // Existence, range and type checks all live in AccountRepository so
    // account creation and password reset can't drift apart.
    final passwordError = AccountRepository.passwordError(password);
    if (passwordError != null) {
      setState(() => _passwordError = passwordError);
      hasError = true;
    }
    if (hasError || !mounted) return;

    // The account isn't created until subject selection returns — if the
    // user cancels the picker, nothing is written, so no half-finished
    // account can ever exist.
    final subjects = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder:
            (_) => SubjectSelectionScreen(
              availableSubjects: widget.availableSubjects,
              initialSelection: const [],
            ),
      ),
    );
    if (subjects == null || !mounted) return;

    final account = await widget.accountRepository.createAccount(
      username: name,
      password: password,
      icon: _selectedIcon,
      subjects: subjects,
    );
    if (!mounted) return;
    Navigator.of(context).pop(account);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Create account',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose a name, a password, and a fun icon.',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        errorText: _nameError,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        errorText: _passwordError,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Your icon',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final emoji in _emojiOptions)
                          GestureDetector(
                            onTap: () => setState(() => _selectedIcon = emoji),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: context.statsBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  width: 2,
                                  color:
                                      _selectedIcon == emoji
                                          ? const Color(0xFF007AFF)
                                          : context.border,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _submit,
                          child: const Text('Next'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
