import 'package:flutter/material.dart';

import 'data/account_repository.dart';
import 'data/study_data_repository.dart';
import 'models/user_account.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/subject_selection_screen.dart';
import 'theme/theme_model.dart';

Future<void> main() async {
  // Needed before using SharedPreferences (inside ThemeModel.load())
  // this early, ahead of runApp.
  WidgetsFlutterBinding.ensureInitialized();

  final themeModel = ThemeModel();
  // Awaited here rather than loaded lazily inside the widget tree, so
  // the app never flashes light mode and then flips to a saved dark
  // preference on the first frame.
  await themeModel.load();

  runApp(VCEUnpackedApp(themeModel: themeModel));
}

class VCEUnpackedApp extends StatefulWidget {
  final ThemeModel themeModel;

  // Optional overrides so widget tests can substitute fakes (asset loads
  // hang under `flutter test`); production uses the const defaults.
  final AccountRepository? accountRepository;
  final StudyDataRepository? studyDataRepository;

  const VCEUnpackedApp({
    super.key,
    required this.themeModel,
    this.accountRepository,
    this.studyDataRepository,
  });

  @override
  State<VCEUnpackedApp> createState() => _VCEUnpackedAppState();
}

class _VCEUnpackedAppState extends State<VCEUnpackedApp> {
  @override
  void dispose() {
    widget.themeModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeModel,
      builder: (context, _) {
        return MaterialApp(
          title: 'VCE Unpacked',
          debugShowCheckedModeBanner: false,
          theme: widget.themeModel.themeData,
          home: AuthGate(
            themeModel: widget.themeModel,
            accountRepository: widget.accountRepository,
            studyDataRepository: widget.studyDataRepository,
          ),
        );
      },
    );
  }
}

/// Root shell that enforces login every time the app launches.
///
/// The active user is deliberately kept only in memory. Nothing stores a
/// "currently logged in" flag, so closing and reopening the app always
/// returns to [LoginScreen].
class AuthGate extends StatefulWidget {
  final ThemeModel themeModel;
  final AccountRepository accountRepository;
  final StudyDataRepository studyDataRepository;

  AuthGate({
    super.key,
    required this.themeModel,
    AccountRepository? accountRepository,
    StudyDataRepository? studyDataRepository,
  })  : accountRepository = accountRepository ?? _DefaultAccountRepository(),
        studyDataRepository = studyDataRepository ?? _DefaultStudyDataRepository();

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  UserAccount? _activeUser;
  late Future<List<String>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = _loadSubjects();
  }

  Future<List<String>> _loadSubjects() async {
    // Small minimum splash delay so the loading spinner actually shows
    // instead of flashing for a frame — parsing the JSON is fast enough
    // that it would otherwise blink in and out.
    final itemsFuture = widget.studyDataRepository.loadItems();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final items = await itemsFuture;
    return items.map((i) => i.subject).toSet().toList()..sort();
  }

  Future<void> _editSubjects(UserAccount account) async {
    // Resolve the subject list up front — the route's builder closure
    // isn't async, and it's already loaded by the time Settings is open.
    final availableSubjects = await _subjectsFuture;
    if (!mounted) return;
    final subjects = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder:
            (_) => SubjectSelectionScreen(
              availableSubjects: availableSubjects,
              initialSelection: account.subjects,
            ),
      ),
    );
    if (subjects == null || !mounted) return;
    final updated = await widget.accountRepository.updateSubjects(
      account.username,
      subjects,
    );
    if (!mounted) return;
    setState(() => _activeUser = updated);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _subjectsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Could not load subjects: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final subjects = snapshot.data!;
        final activeUser = _activeUser;
        if (activeUser == null) {
          return LoginScreen(
            accountRepository: widget.accountRepository,
            availableSubjects: subjects,
            onLogin: (account) => setState(() => _activeUser = account),
          );
        }
        return HomeScreen(
          themeModel: widget.themeModel,
          repository: widget.studyDataRepository,
          account: activeUser,
          onLogout: () => setState(() => _activeUser = null),
          onEditSubjects: () => _editSubjects(activeUser),
        );
      },
    );
  }
}

class _DefaultAccountRepository extends AccountRepository {
  _DefaultAccountRepository();
}

class _DefaultStudyDataRepository extends StudyDataRepository {
  _DefaultStudyDataRepository();
}
