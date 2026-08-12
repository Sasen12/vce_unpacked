import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import '../logic/study_filter.dart';
import '../models/study_item.dart';
import '../models/user_account.dart';
import '../data/study_data_repository.dart';
import '../data/preferences_repository.dart';
import '../widgets/sidebar.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/category_tabs.dart';
import '../widgets/results_list.dart';
import '../widgets/detail_panel.dart';
import '../theme/theme_model.dart';
import '../theme/app_colors.dart';
import '../widgets/settings_slideout.dart';
import '../widgets/loading_screen.dart';

/// Main screen for VCE Unpacked.
///
/// Implements a three-column macOS-style layout:
///   1. Sidebar — subject list (fixed 220 px).
///   2. Centre — search bar, category pills, scrollable result cards,
///      and a footer showing the result count.
///   3. Detail panel — shows the selected item's official text and
///      plain-language explanation (35 % of window width).
///
/// State is managed with plain [setState]; filtering is done entirely
/// in memory via [_applyFilters]. Completion status is persisted via
/// [PreferencesRepository] (SharedPreferences) — study content itself
/// still isn't, since it's re-read fresh from the bundled asset every
/// launch.
class HomeScreen extends StatefulWidget {
  final ThemeModel themeModel;

  // Injectable so widget tests can supply a fake data source — the app
  // always uses the real StudyDataRepository (rootBundle reads hang in
  // `flutter test`, since the test harness never answers asset-load
  // messages), but tests can't load assets, so they pass a repository
  // returning fixture items instead.
  final StudyDataRepository? repository;

  // The logged-in user. Their chosen [UserAccount.subjects] scope every
  // axis of this screen (sidebar, categories, search, completion count).
  final UserAccount account;

  // Wired from AuthGate so Settings can hand control back to the shell:
  // [onEditSubjects] reopens the subject picker, [onLogout] drops the
  // active user and returns to the login screen.
  final VoidCallback? onLogout;
  final VoidCallback? onEditSubjects;

  const HomeScreen({
    super.key,
    required this.themeModel,
    required this.account,
    this.repository,
    this.onLogout,
    this.onEditSubjects,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  late final StudyDataRepository _repository;
  final _preferences = PreferencesRepository();
  Timer? _searchDebounce;

  bool _loading = true;
  String? _loadError;

  String? _selectedSubject;
  String? _selectedCategory;
  StudyItem? _selectedItem;
  List<StudyItem> _items = [];
  List<StudyItem> _filteredItems = [];

  // Populated from the loaded dataset once it arrives — the app no
  // longer hardcodes which subjects exist, since that's driven entirely
  // by whatever source files the backend/ pipeline was run against.
  List<String> _subjects = [];

  // Category filter options, derived from whatever categories the
  // active subject actually has (a subject that has no Key Skills, for
  // example, simply doesn't show that pill) — 'All' is always shown
  // first and selects every category.  New categories the backend ever
  // emits slot in after the canonical ones, alphabetically.
  static const _categoryOrder = [
    'Outcome',
    'Key Knowledge',
    'Key Skill',
    'Command Term',
  ];

  List<String> get _categories {
    final present = <String>{
      for (final item in _items)
        if (item.subject == _selectedSubject) item.category,
    };
    final ordered = [
      for (final category in _categoryOrder)
        if (present.contains(category)) category,
    ];
    final extra = present.difference(_categoryOrder.toSet()).toList()..sort();
    return ['All', ...ordered, ...extra];
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? StudyDataRepository();
    _loadItems();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The subject list may change if the user edits it in Settings, which
    // is a rebuild triggered by AuthGate. Reload items whenever it changes
    // so the sidebar and completion state stay in sync with the new list.
    if (!identical(widget.account.subjects, oldWidget.account.subjects) &&
        !listEquals(widget.account.subjects, oldWidget.account.subjects)) {
      _loadItems();
    }
  }

  Future<void> _loadItems() async {
    try {
      final results = await Future.wait([
        _repository.loadItems(),
        _preferences.loadCompletedIds(widget.account.username),
      ]);
      final allItems = results[0] as List<StudyItem>;
      final completedIds = results[1] as Set<String>;
      // Only the subjects this account selected are shown — the sidebar,
      // category pills, completion count, and search all derive from
      // [_items], so filtering here keeps every axis scoped to the user.
      final items = allItems
          .where((item) => widget.account.subjects.contains(item.subject))
          .toList();
      // The dataset itself is re-read fresh from the bundled asset
      // every launch (it's not user data), but which items a student
      // has marked complete IS user data — restore that onto the
      // freshly-loaded items rather than starting them all unchecked.
      for (final item in items) {
        if (completedIds.contains(item.id)) {
          item.isCompleted = true;
        }
      }
      final subjects = items.map((i) => i.subject).toSet().toList()..sort();
      setState(() {
        _items = items;
        _subjects = subjects;
        _selectedSubject = subjects.isNotEmpty ? subjects.first : null;
        _selectedCategory = 'All';
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Bumped on every filter run and forwarded as the results list's
  // ValueKey — a changed key makes the ListView throw away its state,
  // so a re-filter both drops stale recycled rows and resets the scroll
  // position to the top of the new result set.
  int _filterGeneration = 0;

  /// Re-runs the in-memory filter against [_items] and writes the result
  /// into [_filteredItems].  Three axes are ANDed together (subject,
  /// category, full-text search) by the shared, unit-tested
  /// [filterItems] helper in lib/logic/study_filter.dart.
  void _applyFilters() {
    setState(() {
      _filterGeneration++;
      _filteredItems = filterItems(
        _items,
        subject: _selectedSubject,
        category: _selectedCategory,
        query: _searchController.text,
      );
    });
  }

  /// Count of marked-complete items shown in the toolbar stat chip.
  int get _completedCount => _items.where((i) => i.isCompleted).length;

  void _onSubjectSelected(String subject) {
    setState(() {
      _selectedSubject = subject;
      _selectedItem = null; // clear detail panel when switching subject
      // Reset the category pill if the previous selection isn't a
      // category this subject has (e.g. Key Skill → a subject without
      // any Key Skills), so the list never silently empties.
      if (!_categories.contains(_selectedCategory)) {
        _selectedCategory = 'All';
      }
    });
    _applyFilters();
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _applyFilters();
  }

  // Re-filtering re-scans every item's title/official/plain-language text
  // against the query, which is wasted work for keystrokes that are about
  // to be superseded by the next one — debouncing so it only runs once
  // typing pauses keeps fast typers from feeling the list stutter.
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), _applyFilters);
  }

  void _onItemSelected(StudyItem item) {
    setState(() {
      _selectedItem = item;
    });
  }

  void _onCompletionChanged(bool completed) {
    if (_selectedItem == null) return;
    setState(() {
      _selectedItem!.isCompleted = completed;
    });
    // Fire-and-forget by design: the toggle must feel instant, and a slow
    // disk write shouldn't stall it. Trade-off: the write is best-effort —
    // a failed save loses the mark on next launch with no user feedback.
    _preferences.saveCompletedIds(
      widget.account.username,
      _items.where((i) => i.isCompleted).map((i) => i.id).toSet(),
    );
  }

  /// Opens the settings slideout panel from the right edge, passing it the
  /// active user and the shell callbacks for editing subjects / logging out.
  void _openSettings() {
    SettingsSlideout.show(
      context,
      widget.themeModel,
      account: widget.account,
      onLogout: widget.onLogout,
      onEditSubjects: widget.onEditSubjects,
    );
  }

  String get _emptyMessage {
    if (_searchController.text.isNotEmpty) {
      return 'No matches for “${_searchController.text}” — try a different search term or clear the filter.';
    }
    if (_selectedCategory != null && _selectedCategory != 'All') {
      return 'No $_selectedCategory items found in $_selectedSubject. Try selecting “All” categories.';
    }
    // Check if any subjects are available
    if (_subjects.isEmpty) {
      return 'No study content loaded yet — please run the backend pipeline and copy the output JSON.';
    }
    return 'Select a subject from the sidebar to begin.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceBg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              decoration: BoxDecoration(
                color: context.cardBg,
                border: Border(
                  bottom: BorderSide(color: context.border, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'VCE Unpacked',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  _buildStatChip(
                    context,
                    Icons.check_circle_outline,
                    '$_completedCount / ${_items.length}',
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Settings',
                    child: Tooltip(
                      message: 'Settings',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _openSettings,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: context.statsBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: context.borderStrong,
                              width: 0.5,
                            ),
                          ),
                          child: Icon(
                            Icons.settings,
                            size: 16,
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              // A startup load (or its failure) is a one-time event, so a
              // slightly longer, gentle crossfade here is appropriate —
              // unlike the results list, which updates on every keystroke
              // and deliberately isn't animated.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder:
                    (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                child:
                    _loading
                        ? const LoadingScreen(key: ValueKey('loading'))
                        : _loadError != null
                        ? Center(
                          key: const ValueKey('error'),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Could not load study content.',
                                style: TextStyle(color: context.textPrimary),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.tonal(
                                onPressed: () {
                                  setState(() {
                                    _loading = true;
                                    _loadError = null;
                                  });
                                  _loadItems();
                                },
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        )
                        : LayoutBuilder(
                          builder: (context, constraints) {
                            final showSidebar = constraints.maxWidth >= 700;
                            final showDetails = constraints.maxWidth >= 980;
                            return Row(
                              key: const ValueKey('content'),
                              // Without this, the detail panel — which has
                              // no Expanded/flex child of its own to force
                              // it to fill height, unlike the center list
                              // column — shrink-wraps to its content height
                              // and sits centered in the Row's cross axis,
                              // leaving grey gaps above and below it.
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (showSidebar)
                                  Sidebar(
                                    subjects: _subjects,
                                    selectedSubject: _selectedSubject,
                                    onSubjectSelected: _onSubjectSelected,
                                  ),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: context.cardBg,
                                      border: Border(
                                        right: BorderSide(
                                          color: context.borderStrong,
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        SearchBarWidget(
                                          controller: _searchController,
                                          onChanged: _onSearchChanged,
                                          // Same immediate clear the footer
                                          // "Clear" link performs — cancels
                                          // any pending debounce instead of
                                          // re-scheduling another 200ms wait.
                                          onClear: () {
                                            _searchDebounce?.cancel();
                                            _searchController.clear();
                                            _applyFilters();
                                          },
                                        ),
                                        CategoryTabs(
                                          categories: _categories,
                                          selectedCategory: _selectedCategory,
                                          onCategorySelected:
                                              _onCategorySelected,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          child: Divider(
                                            height: 1,
                                            color: context.border,
                                          ),
                                        ),
                                        Expanded(
                                          child: ResultsList(
                                            items: _filteredItems,
                                            selectedItem: _selectedItem,
                                            onItemSelected: _onItemSelected,
                                            generation: _filterGeneration,
                                            emptyMessage: _emptyMessage,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: context.cardBg,
                                            border: Border(
                                              top: BorderSide(
                                                color: context.border,
                                                width: 0.5,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.search,
                                                size: 12,
                                                color: context.textSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${_filteredItems.length} result${_filteredItems.length == 1 ? '' : 's'}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: context.textSecondary,
                                                ),
                                              ),
                                              if (_searchController
                                                  .text
                                                  .isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                GestureDetector(
                                                  onTap: () {
                                                    _searchDebounce?.cancel();
                                                    _searchController.clear();
                                                    _applyFilters();
                                                  },
                                                  child: Text(
                                                    'Clear',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          context.textPrimary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (showDetails)
                                  SizedBox(
                                    width: constraints.maxWidth * 0.35,
                                    child: DetailPanel(
                                      item: _selectedItem,
                                      onCompletionChanged: _onCompletionChanged,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Small stat badge shown in the toolbar (e.g. "5 / 15" completion count).
  Widget _buildStatChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.statsBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderStrong, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF34C759)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
