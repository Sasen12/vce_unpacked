import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vce_unpacked/data/study_data_repository.dart';
import 'package:vce_unpacked/models/study_item.dart';
import 'package:vce_unpacked/models/user_account.dart';
import 'package:vce_unpacked/screens/home_screen.dart';
import 'package:vce_unpacked/theme/app_colors.dart';
import 'package:vce_unpacked/theme/theme_model.dart';
import 'package:vce_unpacked/widgets/category_tabs.dart';

class _FakeStudyDataRepository extends StudyDataRepository {
  final List<StudyItem> items;
  _FakeStudyDataRepository(this.items);

  @override
  Future<List<StudyItem>> loadItems() async => items;
}

// An account whose subjects match every fixture item, so the default
// fixtures behave exactly as they did before accounts existed.
UserAccount _allSubjectsAccount() => UserAccount(
      username: 'Test Student',
      passwordHash: 'hash',
      salt: 'salt',
      icon: '🦊',
      subjects: const ['General Mathematics', 'Physics'],
    );

List<StudyItem> _fixtureItems() {
  return [
    StudyItem(
      id: '1',
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
      id: '2',
      subject: 'Physics',
      title: 'Title 2',
      category: 'Key Knowledge',
      officialText: 'Characteristics of light.',
      plainLanguageText: 'The traits of light.',
      unit: 'Unit 1',
      areaOfStudy: 'Area of Study 1',
    ),
    StudyItem(
      id: '3',
      subject: 'General Mathematics',
      title: 'Solve equations',
      category: 'Key Skill',
      officialText: 'Solve linear equations.',
      plainLanguageText: 'Work out equations.',
      unit: 'Unit 1',
      areaOfStudy: 'Area of Study 1',
    ),
  ];
}

void main() {
  testWidgets('typing a non-matching query shows the search empty message',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
        home: HomeScreen(
          themeModel: ThemeModel(),
          account: _allSubjectsAccount(),
          repository: _FakeStudyDataRepository(_fixtureItems()),
        ),
      ),
    );
    // Let the (immediately-resolving) fake load finish and rebuild.
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'zzznope');
    // Search is debounced (200ms) — let it fire and rebuild.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(find.textContaining('No matches for “zzznope”'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category pills are derived per subject', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
        home: HomeScreen(
          themeModel: ThemeModel(),
          account: _allSubjectsAccount(),
          repository: _FakeStudyDataRepository(_fixtureItems()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    Finder pill(String label) => find.descendant(
          of: find.byType(CategoryTabs),
          matching: find.text(label),
        );

    // Subjects are sorted, so General Mathematics (alphabetically first)
    // is selected by default: it only has Key Skills.
    expect(pill('All'), findsOneWidget);
    expect(pill('Key Skill'), findsOneWidget);
    expect(pill('Outcome'), findsNothing);
    expect(pill('Key Knowledge'), findsNothing);
    expect(pill('Command Term'), findsNothing);

    // Switching to Physics exposes its Outcome + Key Knowledge pills
    // (still no Command Term — it has no embedded glossary).
    await tester.tap(find.text('Physics'));
    await tester.pump();
    expect(pill('Outcome'), findsOneWidget);
    expect(pill('Key Knowledge'), findsOneWidget);
    expect(pill('Key Skill'), findsNothing);
    expect(pill('Command Term'), findsNothing);

    // Selecting the Key Knowledge pill filters the list to that category
    // (Key Knowledge cards lead with their plain-language headline).
    await tester.tap(pill('Key Knowledge'));
    await tester.pump();
    expect(find.text('The traits of light.'), findsOneWidget);
    expect(find.text('Outcome 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category selection resets when the new subject lacks it',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
        home: HomeScreen(
          themeModel: ThemeModel(),
          account: _allSubjectsAccount(),
          repository: _FakeStudyDataRepository(_fixtureItems()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    Finder pill(String label) => find.descendant(
          of: find.byType(CategoryTabs),
          matching: find.text(label),
        );

    // General Mathematics -> select its Key Skill pill, then switch to
    // Physics which has no Key Skills: the pill must reset to All rather
    // than leaving an empty list.
    await tester.tap(pill('Key Skill'));
    await tester.pump();
    expect(find.text('Work out equations.'), findsOneWidget);

    await tester.tap(find.text('Physics'));
    await tester.pump();
    expect(pill('All'), findsOneWidget);
    expect(find.text('Outcome 1'), findsOneWidget);
    expect(find.text('The traits of light.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('subjects outside the account list are filtered out',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
        home: HomeScreen(
          themeModel: ThemeModel(),
          account: UserAccount(
            username: 'Physics Only',
            passwordHash: 'hash',
            salt: 'salt',
            icon: '🦊',
            subjects: const ['Physics'],
          ),
          repository: _FakeStudyDataRepository(_fixtureItems()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // General Mathematics isn't one of the account's subjects, so its
    // sidebar entry and items must be absent entirely.
    expect(find.text('Physics'), findsOneWidget);
    expect(find.text('General Mathematics'), findsNothing);
    expect(find.text('Work out equations.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
