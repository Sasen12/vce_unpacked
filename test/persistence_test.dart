import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vce_unpacked/data/preferences_repository.dart';
import 'package:vce_unpacked/theme/theme_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PreferencesRepository round-trips completed ids per account', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = PreferencesRepository();

    expect(await repo.loadCompletedIds('alice'), isEmpty);

    await repo.saveCompletedIds('alice', {'sd-outcome-1', 'sd-key-knowledge-3'});
    expect(
      await repo.loadCompletedIds('alice'),
      {'sd-outcome-1', 'sd-key-knowledge-3'},
    );
    // Completion is scoped per account: Bob can't see Alice's progress.
    expect(await repo.loadCompletedIds('bob'), isEmpty);
  });

  test('PreferencesRepository round-trips dark mode', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = PreferencesRepository();

    expect(await repo.loadDarkMode(), isFalse);
    await repo.saveDarkMode(true);
    expect(await repo.loadDarkMode(), isTrue);
  });

  test('ThemeModel.load() picks up a previously saved dark mode preference', () async {
    SharedPreferences.setMockInitialValues({'dark_mode': true});
    final model = ThemeModel();
    expect(model.isDark, isFalse); // default before load()

    await model.load();
    expect(model.isDark, isTrue);
  });

  test('ThemeModel.toggleTheme() persists the new value', () async {
    SharedPreferences.setMockInitialValues({});
    final model = ThemeModel();
    await model.load();
    expect(model.isDark, isFalse);

    model.toggleTheme();
    expect(model.isDark, isTrue);

    // New instance simulating an app restart -> should read the saved value.
    final restarted = ThemeModel();
    await restarted.load();
    expect(restarted.isDark, isTrue);
  });
}
