import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vce_unpacked/data/account_repository.dart';
import 'package:vce_unpacked/data/study_data_repository.dart';
import 'package:vce_unpacked/main.dart';
import 'package:vce_unpacked/models/study_item.dart';
import 'package:vce_unpacked/theme/theme_model.dart';

class _FakeStudyDataRepository extends StudyDataRepository {
  @override
  Future<List<StudyItem>> loadItems() async => const [];
}

void main() {
  testWidgets('App renders the login gate on launch', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    // The real StudyDataRepository reads a bundled asset, which hangs under
    // `flutter test` — inject an empty fake so the AuthGate resolves its
    // subject list and reaches LoginScreen.
    await tester.pumpWidget(
      VCEUnpackedApp(
        themeModel: ThemeModel(),
        accountRepository: AccountRepository(),
        studyDataRepository: _FakeStudyDataRepository(),
      ),
    );
    await tester.pump();
    await tester.pump();

    // The login gate — not the main app — is the first screen, seeded with
    // the two demo accounts.
    expect(find.text('VCE Unpacked'), findsOneWidget);
    expect(
      find.text('Choose your profile, then enter your password.'),
      findsOneWidget,
    );
    expect(find.text('Demo Student'), findsOneWidget);
    expect(find.text('Demo Friend'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}
