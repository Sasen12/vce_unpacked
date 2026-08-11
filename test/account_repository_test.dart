import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vce_unpacked/data/account_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('create, find, and verify an account', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = AccountRepository();

    await repo.createAccount(
      username: '  Alice  ',
      password: 's3cret',
      icon: '🦊',
      subjects: ['Physics'],
    );

    final account = await repo.findAccount('alice');
    expect(account, isNotNull);
    expect(account!.username, 'Alice'); // whitespace trimmed
    expect(account.icon, '🦊');
    expect(account.subjects, ['Physics']);

    expect(await repo.verifyPassword('alice', 's3cret'), isTrue);
    expect(await repo.verifyPassword('alice', 'wrong'), isFalse);
    expect(await repo.verifyPassword('nobody', 's3cret'), isFalse);
  });

  test('password is hashed, never stored in plaintext, with per-account salt',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = AccountRepository();

    await repo.createAccount(
      username: 'Alice',
      password: 'hunter2',
      icon: '🦊',
      subjects: ['Physics'],
    );
    await repo.createAccount(
      username: 'Bob',
      password: 'hunter2',
      icon: '🐼',
      subjects: ['Media'],
    );

    final alice = await repo.findAccount('Alice');
    final bob = await repo.findAccount('Bob');
    expect(alice!.passwordHash, isNot('hunter2'));
    expect(alice.salt, isNot(bob!.salt));
    // Same plaintext password, but different salts -> different hashes.
    expect(alice.passwordHash, isNot(bob.passwordHash));
  });

  test('updateSubjects replaces the account subject list', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = AccountRepository();

    await repo.createAccount(
      username: 'Alice',
      password: 'pw',
      icon: '🦊',
      subjects: ['Physics'],
    );

    final updated = await repo.updateSubjects('alice', ['Media', 'Philosophy']);
    expect(updated.subjects, ['Media', 'Philosophy']);

    final found = await repo.findAccount('Alice');
    expect(found!.subjects, ['Media', 'Philosophy']);
  });

  test('duplicate username is rejected case-insensitively', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = AccountRepository();

    await repo.createAccount(
      username: 'Alice',
      password: 'pw',
      icon: '🦊',
      subjects: ['Physics'],
    );

    await expectLater(
      repo.createAccount(
        username: 'alice',
        password: 'other',
        icon: '🐼',
        subjects: ['Media'],
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('empty password or subject list is rejected', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = AccountRepository();

    await expectLater(
      repo.createAccount(
        username: 'Alice',
        password: '',
        icon: '🦊',
        subjects: ['Physics'],
      ),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      repo.createAccount(
        username: 'Alice',
        password: 'pw',
        icon: '🦊',
        subjects: [],
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('first load seeds the two demo accounts, later loads do not',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = AccountRepository();

    final accounts = await repo.loadAccountsWithDemoDefaults();
    expect(accounts.length, 2);
    expect(accounts[0].username, AccountRepository.demoUsername1);
    expect(accounts[1].username, AccountRepository.demoUsername2);

    // A user-created account on top of the demos stays; no extra demos.
    await repo.createAccount(
      username: 'Alice',
      password: 'pw',
      icon: '🦊',
      subjects: ['Physics'],
    );
    final again = await repo.loadAccountsWithDemoDefaults();
    expect(again.length, 3);
    expect(again.map((a) => a.username), contains('Alice'));

    // Demo passwords actually unlock the demo accounts.
    expect(
      await repo.verifyPassword(
        AccountRepository.demoUsername1,
        AccountRepository.demoPassword1,
      ),
      isTrue,
    );
    expect(
      await repo.verifyPassword(
        AccountRepository.demoUsername2,
        AccountRepository.demoPassword2,
      ),
      isTrue,
    );
  });

  test('legacy global completed ids fold into the first account', () async {
    SharedPreferences.setMockInitialValues({
      'completed_item_ids': ['legacy-1', 'legacy-2'],
    });
    final repo = AccountRepository();

    await repo.createAccount(
      username: 'Alice',
      password: 'pw',
      icon: '🦊',
      subjects: ['Physics'],
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('completed_item_ids'), isNull);
    expect(
      prefs.getStringList(repo.completedIdsKeyFor('Alice')),
      ['legacy-1', 'legacy-2'],
    );
  });
}
