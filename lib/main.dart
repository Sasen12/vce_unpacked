import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'data/account_repository.dart';
import 'data/study_data_repository.dart';
import 'models/user_account.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/subject_selection_screen.dart';
import 'theme/app_colors.dart';
import 'theme/theme_model.dart';

Future<void> main() async {
  // Needed before using SharedPreferences (inside ThemeModel.load())
  // this early, ahead of runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop window setup. Launches straight into fullscreen so the study
  // browser takes over the whole screen (works for the local macOS build
  // and the Windows exe produced by GitHub Actions alike).
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(fullScreen: true),
  );

  final themeModel = ThemeModel();
  // Awaited here rather than loaded lazily inside the widget tree, so
  // the app never flashes light mode and then flips to a saved dark
  // preference on the first frame. Guarded so a SharedPreferences read
  // failure on the launching machine can't blank the window before the
  // first frame renders — falling back to the light default is safe.
  try {
    await themeModel.load();
  } catch (_) {
    // Swallow: ThemeModel already defaults to light mode, so the app
    // just starts with the default theme instead of failing to launch.
  }

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
    // Keep the splash up long enough to actually read it (the logo,
    // the app name, the "Reading study content..." line) instead of
    // letting it flash by. The real load runs in parallel underneath,
    // so this is just a minimum hold, not extra wait on top.
    final itemsFuture = widget.studyDataRepository.loadItems();
    await Future<void>.delayed(const Duration(milliseconds: 2500));
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
          return const _StartupLoading();
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

/// Branded splash shown while the study dataset is read before login.
/// Mirrors the login screen's icon + title block so startup doesn't just
/// flash a bare spinner on a plain background.
class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceBg,
      body: SafeArea(
        child: Center(
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
                'Reading study content...',
                style: TextStyle(fontSize: 14, color: context.textSecondary),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF007AFF)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
