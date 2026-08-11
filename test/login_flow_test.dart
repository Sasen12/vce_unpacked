import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vce_unpacked/data/account_repository.dart';
import 'package:vce_unpacked/data/study_data_repository.dart';
import 'package:vce_unpacked/main.dart';
import 'package:vce_unpacked/models/study_item.dart';
import 'package:vce_unpacked/theme/theme_model.dart';

class _FakeStudyDataRepository extends StudyDataRepository {
  final List<StudyItem> items;
  _FakeStudyDataRepository(this.items);

  @override
  Future<List<StudyItem>> loadItems() async => items;
}

List<StudyItem> _fixtureItems() {
  return [
    StudyItem(
      id: 'physics-1',
      subject: 'Physics',
      title: 'Outcome 1',
      category: 'Outcome',
      officialText: 'Investigate waves.',
      plainLanguageText: 'Study how waves behave.',
      unit: 'Unit 1',
      areaOfStudy: 'Area of Study 1',
      outcome: 'Outcome 1',
    ),
    StudyItem(
      id: 'media-1',
      subject: 'Media',
      title: 'Narrative',
      category: 'Outcome',
      officialText: 'Analyse narrative structures.',
      plainLanguageText: 'Look at how stories are built.',
      unit: 'Unit 1',
      areaOfStudy: 'Area of Study 1',
      outcome: 'Outcome 1',
    ),
  ];
}

Widget _app() => VCEUnpackedApp(
      themeModel: ThemeModel(),
      accountRepository: AccountRepository(),
      studyDataRepository: _FakeStudyDataRepository(_fixtureItems()),
    );

void main() {
  testWidgets('demo account login reaches HomeScreen', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Login screen shows the two demo accounts.
    expect(find.text('Demo Student'), findsOneWidget);

    // Tapping a chip demands a password before entering.
    await tester.tap(find.text('Demo Student'));
    await tester.pumpAndSettle();
    expect(find.text('Password'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'demo123');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    // HomeScreen is now showing — the login screen is gone and the demo
    // account's filtered subjects appear in the sidebar.
    expect(find.text('Demo Student'), findsNothing);
    expect(find.text('Physics'), findsOneWidget);
    expect(find.text('Media'), findsNothing);
    expect(find.text('Study how waves behave.'), findsOneWidget);
  });

  testWidgets('demo login rejects a wrong password', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Demo Friend'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'not-the-password');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    // Still on the login screen with an inline error — no HomeScreen.
    expect(find.text('Wrong password. Try again.'), findsOneWidget);
    expect(find.text('Study how waves behave.'), findsNothing);
  });

  testWidgets('account creation: name, password, subjects, then HomeScreen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    // Fill in name + password.
    await tester.enterText(find.byType(TextField).at(0), 'Alice');
    await tester.enterText(find.byType(TextField).at(1), 's3cret');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Subject selection: Done is disabled until at least one is chosen.
    expect(find.text('Select at least one subject'), findsOneWidget);
    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();
    expect(find.text('1 subject selected'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // HomeScreen appears, scoped to Alice's single subject.
    expect(find.text('Alice'), findsNothing); // no longer on the login screen
    expect(find.text('Media'), findsOneWidget);
    expect(find.text('Look at how stories are built.'), findsOneWidget);
    expect(find.text('Physics'), findsNothing);
  });
}
