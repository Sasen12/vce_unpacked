import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_account.dart';

/// Local, on-device account store.
///
/// This is deliberately not real server authentication: accounts never
/// leave the device and are stored in SharedPreferences as one JSON blob.
/// Passwords are still not stored as plaintext — each one is SHA-256 hashed
/// with a per-account random salt — but this is demo-grade protection for
/// an offline classroom tool, not a substitute for PBKDF2/bcrypt + a real
/// auth backend.
class AccountRepository {
  static const _accountsKey = 'user_accounts';
  static const _legacyCompletedIdsKey = 'completed_item_ids';

  static const demoUsername1 = 'Demo Student';
  static const demoPassword1 = 'demo123';
  static const demoUsername2 = 'Demo Friend';
  static const demoPassword2 = 'friend123';

  static const _demoSubjects1 = [
    'Physics',
    'Mathematical Methods',
    'Specialist Mathematics',
  ];
  static const _demoSubjects2 = [
    'English EAL',
    'Media',
    'Philosophy',
  ];

  final Random _random;

  AccountRepository({Random? random}) : _random = random ?? Random.secure();

  Future<List<UserAccount>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((json) => UserAccount.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // Seeds two demo accounts on a completely fresh install so the login
  // screen has something to show before anyone has signed up — the demo
  // credentials are printed on the login screen itself. Only runs while
  // the store is empty; once a real account exists it's never touched.
  Future<List<UserAccount>> loadAccountsWithDemoDefaults() async {
    final accounts = await loadAccounts();
    if (accounts.isNotEmpty) return accounts;

    await createAccount(
      username: demoUsername1,
      password: demoPassword1,
      icon: '🦊',
      subjects: _demoSubjects1,
    );
    await createAccount(
      username: demoUsername2,
      password: demoPassword2,
      icon: '🐼',
      subjects: _demoSubjects2,
    );
    return loadAccounts();
  }

  Future<UserAccount?> findAccount(String username) async {
    final normalized = username.trim().toLowerCase();
    for (final account in await loadAccounts()) {
      if (account.username.trim().toLowerCase() == normalized) {
        return account;
      }
    }
    return null;
  }

  Future<UserAccount> createAccount({
    required String username,
    required String password,
    required String icon,
    required List<String> subjects,
  }) async {
    final trimmedUsername = username.trim();
    if (trimmedUsername.isEmpty) {
      throw ArgumentError('Username cannot be empty.');
    }
    if (password.isEmpty) {
      throw ArgumentError('Password cannot be empty.');
    }
    if (subjects.isEmpty) {
      throw ArgumentError('At least one subject must be selected.');
    }
    if (await findAccount(trimmedUsername) != null) {
      throw ArgumentError('That username is already taken.');
    }

    final accounts = await loadAccounts();
    final salt = _newSalt();
    final account = UserAccount(
      username: trimmedUsername,
      passwordHash: _hashPassword(password, salt),
      salt: salt,
      icon: icon,
      subjects: List.unmodifiable(subjects),
    );

    await _saveAccounts([...accounts, account]);
    // The very first account created absorbs any completion marks left
    // behind by the pre-account single-user version of the app, so a
    // student upgrading doesn't lose their progress. Deliberately only
    // when the store was empty — later accounts each get their own.
    if (accounts.isEmpty) {
      await _foldLegacyCompletedIdsInto(trimmedUsername);
    }
    return account;
  }

  Future<bool> verifyPassword(String username, String password) async {
    final account = await findAccount(username);
    if (account == null) return false;
    return _hashPassword(password, account.salt) == account.passwordHash;
  }

  Future<UserAccount> resetPassword(String username, String newPassword) async {
    if (newPassword.isEmpty) {
      throw ArgumentError('Password cannot be empty.');
    }
    final accounts = await loadAccounts();
    final index = accounts.indexWhere(
      (account) =>
          account.username.trim().toLowerCase() == username.trim().toLowerCase(),
    );
    if (index == -1) {
      throw ArgumentError('Account not found.');
    }

    final salt = _newSalt();
    final updated = accounts[index].copyWith(
      passwordHash: _hashPassword(newPassword, salt),
      salt: salt,
    );
    accounts[index] = updated;
    await _saveAccounts(accounts);
    return updated;
  }

  Future<UserAccount> updateSubjects(String username, List<String> subjects) async {
    if (subjects.isEmpty) {
      throw ArgumentError('At least one subject must be selected.');
    }
    final accounts = await loadAccounts();
    final index = accounts.indexWhere(
      (account) =>
          account.username.trim().toLowerCase() == username.trim().toLowerCase(),
    );
    if (index == -1) {
      throw ArgumentError('Account not found.');
    }

    final updated = accounts[index].copyWith(subjects: List.unmodifiable(subjects));
    accounts[index] = updated;
    await _saveAccounts(accounts);
    return updated;
  }

  Future<void> _saveAccounts(List<UserAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await prefs.setString(_accountsKey, encoded);
  }

  String _newSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPassword(String password, String salt) {
    return sha256.convert(utf8.encode('$salt:$password')).toString();
  }

  String completedIdsKeyFor(String username) {
    // Mirrors PreferencesRepository's key scheme — the two classes must
    // stay in sync, since this one only exists to migrate data between
    // keys. Prefer PreferencesRepository for new callers.
    return 'completed_item_ids_${username.trim().toLowerCase()}';
  }

  // Migrates the legacy shared `completed_item_ids` blob (written before
  // accounts existed) into the first account's per-user key, then removes
  // it so the migration runs exactly once.
  Future<void> _foldLegacyCompletedIdsInto(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getStringList(_legacyCompletedIdsKey);
    if (legacy == null) return;
    await prefs.setStringList(completedIdsKeyFor(username), legacy);
    await prefs.remove(_legacyCompletedIdsKey);
  }
}
