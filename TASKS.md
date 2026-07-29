# Attendance App — Flutter Refactoring Task Tracker

> **Last Updated**: 2026-07-30
> **Current Branch**: `fix` (branched from `abhishek`)
> **Target Branch for PRs**: `abhishek`
> **Full Plan Reference**: `implementation_plan.md` (in AI brain artifacts)
> **Audit Report Reference**: `flutter_audit_report.md` (in AI brain artifacts)

---

## How to Use This File

- `[ ]` = Not started
- `[/]` = In progress
- `[x]` = Done / Merged
- `[~]` = Skipped / Deferred with reason noted

Update this file with every commit and PR. Any AI agent continuing this work **must read this file first**.

---

## Context for AI Agents

This is a **Flutter + Dart** attendance management system (web + Android).

| Item | Detail |
|---|---|
| **Flutter skill rules** | `.Skills/flutter_skill.md` — READ before writing any Flutter code |
| **State management** | `ChangeNotifier` + `Provider` only. NO Riverpod, NO Bloc, NO GetX |
| **DI pattern** | Manual constructor injection. No `get_it`. Use `ApiService.instance` singleton |
| **Routing** | `go_router` (to be added in Phase 5) |
| **Models** | `json_serializable` + `@JsonSerializable(fieldRename: FieldRename.snake)` |
| **Linting** | `avoid_print`, `prefer_single_quotes`, `always_use_package_imports` |
| **Adaptive UI** | Each screen has separate `_MobileView` + `_DesktopView` widget trees via `ResponsiveLayout` |
| **Breakpoint** | Mobile < 768dp, Desktop >= 768dp, Expanded nav >= 1200dp |
| **Commit style** | `<type>(<scope>): <summary>` e.g. `fix(api): add 30s timeout` |
| **API service** | `lib/services/api_service.dart` — 830 lines, `package:http` |
| **God file** | `lib/screens/admin_dashboard.dart` — 5,873 lines, MUST be split |

---

## Completed Work (Before This Plan)

- [x] Initial Flutter app created (login, admin dashboard, teacher dashboard, mark attendance)
- [x] `AppTheme` — Material 3 theme, light + dark
- [x] `AppLogger` — sanitised, bounded at 250 entries, debug-only
- [x] `FlutterSecureStorage` for token persistence
- [x] JWT auto-refresh on 401 in `ApiService._send()`
- [x] `SearchableDropdown` widget with full keyboard nav
- [x] `ApiException` typed error class
- [x] `ApiPage<T>` pagination abstraction
- [x] `fix` branch created from `abhishek` ✅
- [x] `lib/core/app_constants.dart` file created (not yet committed)

---

## PHASE 0 — Foundations

> **Branch**: `fix` → PR to `abhishek`
> **Goal**: No visible behaviour change. Establish quality baseline.
> **Status**: 🟡 IN PROGRESS

---

### PR 0.1 — App Constants + Analysis Options

**Commit message style**: `chore(core): ...`
**Status**: 🟡 In progress

#### Tasks

- [x] Create `lib/core/app_constants.dart` with all shared constants
  - [x] `kWideBreakpoint = 768.0`
  - [x] `kChartHeight = 240.0`
  - [x] `kRosterItemExtent = 68.0`
  - [x] `kDefaultAttendanceThreshold = 75.0`
  - [x] `kDefaultPageSize = 100`
  - [x] `kMaxLogEntries = 250`
  - [x] `kRequestTimeout = Duration(seconds: 30)`
  - [x] `kAnalyticsDebounce = Duration(milliseconds: 400)`
  - [x] `kListCacheTtl`, `kScheduleCacheTtl`, `kAnalyticsCacheTtl`
  - [ ] Add layout/responsive constants (from Phase 6 plan):
    - [ ] `kExpandedNavBreakpoint = 1200.0`
    - [ ] `kNavRailWidth = 72.0`
    - [ ] `kNavDrawerWidth = 256.0`
    - [ ] `kDesktopDialogMaxWidth = 520.0`
    - [ ] `kDesktopContentMaxWidth = 1400.0`
    - [ ] `kBottomNavHeight = 80.0`
    - [ ] `kMinTapTarget = 48.0`
    - [ ] `kMobilePadding = EdgeInsets.all(16.0)`
    - [ ] `kDesktopPadding = EdgeInsets.all(24.0)`
- [ ] **Commit 1**: `chore(core): add AppConstants with all shared magic values`

- [ ] Update `analysis_options.yaml`:
  - [ ] Add `avoid_print: true`
  - [ ] Add `prefer_single_quotes: true`
  - [ ] Add `always_use_package_imports: true`
  - [ ] Add `prefer_final_fields: true`
  - [ ] Add `prefer_const_constructors: true`
  - [ ] Add `prefer_const_declarations: true`
  - [ ] Add `use_super_parameters: true`
  - [ ] Add `unnecessary_await_in_return: true`
  - [ ] Add `sort_constructors_first: true`
  - [ ] Add `avoid_dynamic_calls: warning` under `analyzer.errors`
  - [ ] Add `missing_return: error` under `analyzer.errors`
  - [ ] Exclude `**/*.g.dart` and `**/*.freezed.dart`
- [ ] **Commit 2**: `chore(core): update analysis_options.yaml with project lint rules`

- [ ] Run `dart fix --apply` then `dart format lib/`
- [ ] **Commit 3**: `chore(core): run dart fix and dart format across entire lib/`

- [ ] Replace all magic numbers with `AppConstants.*`:
  - [ ] `lib/screens/mark_attendance_screen.dart` — `> 700` → `AppConstants.kWideBreakpoint`
  - [ ] `lib/screens/teacher_dashboard.dart` — `> 768` → `AppConstants.kWideBreakpoint`
  - [ ] `lib/screens/admin_dashboard.dart` — `> 720`, `75`, `100` → constants
  - [ ] `lib/utils/app_logger.dart` — `250` → `AppConstants.kMaxLogEntries`
- [ ] **Commit 4**: `refactor(core): replace all magic numbers with AppConstants`

- [ ] **PR 0.1 opened** → target `abhishek`
- [ ] PR review checklist passed
- [ ] PR merged

---

### PR 0.2 — HTTP Request Timeout + mounted check fix

**Status**: ⬜ Not started

#### Tasks

- [ ] Add `dart:async` import to `api_service.dart`
- [ ] Add `.timeout(AppConstants.kRequestTimeout)` in `ApiService._send()`
- [ ] Catch `TimeoutException` in `_processResponse()` → map to `ApiException` with code `TIMEOUT`, status `408`
- [ ] **Commit 1**: `fix(api): add 30-second timeout to all HTTP requests in ApiService`

- [ ] In `lib/screens/teacher_dashboard.dart`, find the `Navigator.of(context).push(...)` call that opens `MarkAttendanceScreen`
- [ ] Add `if (!mounted) return;` immediately after the `await` resolves
- [ ] **Commit 2**: `fix(nav): add mounted check after Navigator.push in TeacherDashboard`

- [ ] **PR 0.2 opened** → target `abhishek`
- [ ] PR merged

---

### PR 0.3 — Singleton ApiService

**Status**: ⬜ Not started

#### Tasks

- [ ] Convert `ApiService` to a singleton using a private constructor + `static final instance`
  - [ ] Add `ApiService._()` private constructor
  - [ ] Add `static final ApiService instance = ApiService._();`
- [ ] **Commit 1**: `refactor(core): make ApiService a singleton via factory constructor`

- [ ] Update `AuthProvider` to accept `ApiService` via constructor:
  - [ ] Add `AuthProvider({required ApiService apiService})` constructor
  - [ ] Store as `final ApiService _apiService`
  - [ ] Update `main.dart` to pass `ApiService.instance`
- [ ] **Commit 2**: `refactor(auth): inject ApiService singleton into AuthProvider`

- [ ] `lib/screens/teacher_dashboard.dart` — replace `ApiService()` with `ApiService.instance`
- [ ] **Commit 3**: `refactor(teacher): use ApiService.instance instead of ApiService()`

- [ ] `lib/screens/admin_dashboard.dart` — replace `ApiService()` with `ApiService.instance`
- [ ] **Commit 4**: `refactor(admin): use ApiService.instance instead of ApiService()`

- [ ] `lib/screens/mark_attendance_screen.dart` + `lib/widgets/profile_modal.dart` — same fix
- [ ] **Commit 5**: `refactor(attendance): use ApiService.instance in screen and profile modal`

- [ ] Run `dart analyze` — must be zero errors
- [ ] **PR 0.3 opened** → target `abhishek`
- [ ] PR merged

---

## PHASE 1 — Quick-Win Performance Fixes

> **Branch**: new `perf/quick-wins` from `abhishek`
> **Goal**: Measurable load time improvement with minimal risk
> **Status**: ⬜ Not started
> **Expected outcome**: Dashboard load 3–5s → < 1s

---

### PR 1.1 — Parallelize Teacher Dashboard API Calls

**Status**: ⬜ Not started

#### Tasks

- [ ] Rewrite `TeacherDashboard._loadTeacherData()`:
  - [ ] Phase 1 parallel: `Future.wait([getWeeklySchedule, getSchoolHolidays, getMyClass, listClasses])`
  - [ ] Resolve `_selectedClass` from parallel results before Phase 2
- [ ] **Commit 1**: `perf(teacher): parallelize Phase 1 API calls (schedule, class, holidays)`

- [ ] Rewrite `TeacherDashboard._loadClassDataAndAnalytics()`:
  - [ ] Phase 2 parallel: `Future.wait([getClassSummary, getClassDefaulters, getClassRoster, getMonthlyMatrix, listSessions])`
  - [ ] Keep Phase 3 lazy: `getAttendanceSession` only if session exists
- [ ] **Commit 2**: `perf(teacher): parallelize Phase 2 API calls (summary, defaulters, roster, matrix, sessions)`

- [ ] Replace all manual date strings with `DateFormat` from `intl`:
  - [ ] `"${now.year}-${now.month.toString().padLeft(2,'0')}-01"` → `DateFormat('yyyy-MM-01').format(now)`
  - [ ] Apply in: `teacher_dashboard.dart`, `admin_dashboard.dart`, `api_service.dart`
- [ ] **Commit 3**: `refactor(teacher): replace manual date strings with DateFormat`

- [ ] Verify with network tab: requests show as parallel, not waterfall
- [ ] **PR 1.1 opened** → target `abhishek`
- [ ] PR merged

---

### PR 1.2 — Parallelize Admin Analytics + Debounce

**Status**: ⬜ Not started

#### Tasks

- [ ] In `_AnalyticsTabState._loadAllAnalytics()`, wrap 3 sequential calls in `Future.wait([...])`
- [ ] **Commit 1**: `perf(admin): parallelize getSchoolOverview, getDefaulters, and getTrend calls`

- [ ] Add `Timer? _debounceTimer` to `_AnalyticsTabState`
- [ ] Add `_scheduleAnalyticsReload()` method with `AppConstants.kAnalyticsDebounce`
- [ ] Replace all `_loadAllAnalytics()` calls in `onChanged` handlers with `_scheduleAnalyticsReload()`
- [ ] Cancel timer in `dispose()`
- [ ] **Commit 2**: `fix(admin): debounce analytics reload to prevent redundant API calls`

- [ ] **PR 1.2 opened** → target `abhishek`
- [ ] PR merged

---

### PR 1.3 — RepaintBoundary + MediaQuery + ListView Performance

**Status**: ⬜ Not started

#### Tasks

- [ ] Wrap `BarChart` in `RepaintBoundary` in `_AnalyticsTab`
- [ ] Wrap `LineChart` in `RepaintBoundary` in `_AnalyticsTab`
- [ ] **Commit 1**: `perf(admin): wrap BarChart and LineChart in RepaintBoundary`

- [ ] Replace `MediaQuery.of(context).size.width` with `MediaQuery.sizeOf(context).width` in:
  - [ ] `teacher_dashboard.dart`
  - [ ] `admin_dashboard.dart`
  - [ ] `mark_attendance_screen.dart`
- [ ] **Commit 2**: `perf(screens): replace MediaQuery.of().size with MediaQuery.sizeOf()`

- [ ] In `MarkAttendanceScreen`, add cached count state variables:
  - [ ] `int _presentCount`, `_absentCount`, `_lateCount`, `_excusedCount`
  - [ ] Add `_updateStatusCounts()` method
  - [ ] Call it in `_loadSessionRoster()`, `_markAllAs()`, individual status `onSelected`
  - [ ] Remove 5x O(n) computations from `build()`
- [ ] Add `itemExtent: AppConstants.kRosterItemExtent` to `ListView.separated`
- [ ] Add `cacheExtent: 400` to the same ListView
- [ ] **Commit 3**: `perf(attendance): add itemExtent and cache roster status counts`

- [ ] **PR 1.3 opened** → target `abhishek`
- [ ] PR merged

---

## PHASE 2 — Admin Dashboard Decomposition

> **Branch**: new `refactor/admin-split` from `abhishek`
> **Goal**: Break 5,873-line god file into 7 focused tab files
> **Status**: ⬜ Not started
> **Risk**: Low — pure structural refactor, no logic change

---

### PR 2.1 — Split admin_dashboard.dart (8 commits)

**Status**: ⬜ Not started

#### New directory structure

```
lib/screens/admin/
├── admin_dashboard.dart       ← shell only (~150 lines)
├── tabs/
│   ├── sessions_tab.dart
│   ├── analytics_tab.dart
│   ├── classes_tab.dart
│   ├── teachers_tab.dart
│   ├── students_tab.dart
│   ├── reports_tab.dart
│   └── school_days_tab.dart
└── widgets/
    ├── kpi_card.dart
    └── stat_chip.dart
```

#### Tasks

- [ ] Create `lib/screens/admin/widgets/kpi_card.dart` — extract `_kpiCard()` method as `KpiCard extends StatelessWidget`
- [ ] Create `lib/screens/admin/widgets/stat_chip.dart` — extract `_statChip()` as `StatChip extends StatelessWidget`
- [ ] **Commit 1**: `refactor(admin): extract shared admin widgets (KpiCard, StatChip)`

- [ ] Move `_AnalyticsTab` + `_AnalyticsTabState` to `lib/screens/admin/tabs/analytics_tab.dart`
- [ ] Update imports in `admin_dashboard.dart`
- [ ] **Commit 2**: `refactor(admin): extract AnalyticsTab into tabs/analytics_tab.dart`

- [ ] Move `_AcademicSessionsTab` to `lib/screens/admin/tabs/sessions_tab.dart`
- [ ] **Commit 3**: `refactor(admin): extract SessionsTab into tabs/sessions_tab.dart`

- [ ] Move `_ClassesTab` to `lib/screens/admin/tabs/classes_tab.dart`
- [ ] **Commit 4**: `refactor(admin): extract ClassesTab into tabs/classes_tab.dart`

- [ ] Move `_TeachersTab` to `lib/screens/admin/tabs/teachers_tab.dart`
- [ ] **Commit 5**: `refactor(admin): extract TeachersTab into tabs/teachers_tab.dart`

- [ ] Move `_StudentsTab` to `lib/screens/admin/tabs/students_tab.dart`
- [ ] **Commit 6**: `refactor(admin): extract StudentsTab into tabs/students_tab.dart`

- [ ] Move `_ReportsTab` + `_SchoolDaysTab` to their respective files
- [ ] **Commit 7**: `refactor(admin): extract ReportsTab and SchoolDaysTab to separate files`

- [ ] Replace tab `List` in `build()` with `IndexedStack`
  - [ ] Each tab implements `AutomaticKeepAliveClientMixin`
  - [ ] `admin_dashboard.dart` shell is < 200 lines after this
- [ ] **Commit 8**: `refactor(admin): replace tab list with IndexedStack to prevent eager init`

- [ ] Verify: switching tabs does NOT trigger new API calls (check DevTools network)
- [ ] Verify: all 7 tabs render correctly
- [ ] **PR 2.1 opened** → target `abhishek`
- [ ] PR merged

---

## PHASE 3 — MVVM ViewModels

> **Branch**: new `feat/mvvm` from `abhishek`
> **Goal**: Extract all business logic from widget State into ChangeNotifier ViewModels
> **Status**: ⬜ Not started
> **Key rule**: ViewModel has NO BuildContext. Pure Dart class.

---

### PR 3.1 — TeacherViewModel

**Status**: ⬜ Not started

#### New files

```
lib/features/teacher/
├── teacher_state.dart
├── teacher_view_model.dart
├── teacher_dashboard_screen.dart
└── widgets/
    ├── teacher_header_card.dart
    ├── teacher_control_toolbar.dart
    ├── teacher_kpi_cards.dart
    ├── teacher_attendance_card.dart
    ├── teacher_monthly_register.dart
    └── teacher_defaulters_section.dart
```

#### Tasks

- [ ] Create `TeacherState` immutable data class with `copyWith()`
- [ ] **Commit 1**: `feat(teacher): create TeacherState data class`

- [ ] Create `TeacherViewModel extends ChangeNotifier`:
  - [ ] Constructor takes `ApiService apiService`
  - [ ] `loadDashboard()` — Phase 1 parallel API calls
  - [ ] `loadClassData()` — Phase 2 parallel API calls
  - [ ] `openOrCreateSession(DateTime date)`
  - [ ] `switchClass(SchoolClass newClass)`
  - [ ] `changeDate(DateTime date)`
  - [ ] Zero `BuildContext` references
- [ ] **Commit 2**: `feat(teacher): implement TeacherViewModel with parallel API loading`

- [ ] Extract each `_buildXxx()` method to its own `StatelessWidget` file
- [ ] **Commit 3**: `refactor(teacher): decompose TeacherDashboard into pure UI widgets`

- [ ] Create `TeacherDashboardScreen` → `ChangeNotifierProvider<TeacherViewModel>` → `_TeacherDashboardView`
- [ ] `_TeacherDashboardView` uses `context.watch<TeacherViewModel>()` to read state
- [ ] Delete old `lib/screens/teacher_dashboard.dart` (or move it)
- [ ] Update router/AuthGate to point to new screen location
- [ ] **Commit 4**: `refactor(teacher): replace TeacherDashboard StatefulWidget with ViewModel-driven screen`

- [ ] **PR 3.1 opened** → target `abhishek`
- [ ] PR merged

---

### PR 3.2 — AttendanceViewModel

**Status**: ⬜ Not started

#### Tasks

- [ ] Create `AttendanceViewModel extends ChangeNotifier`:
  - [ ] Holds `List<RosterEntry> _roster`
  - [ ] Cached: `int presentCount`, `absentCount`, `lateCount`, `excusedCount`
  - [ ] `loadSessionRoster(String sessionId)`
  - [ ] `updateStatus(String studentId, String newStatus)` → calls `_updateCounts()`
  - [ ] `markAll(String status)` → calls `_updateCounts()`
  - [ ] `saveAndClose()`
  - [ ] `reopenSession()`
- [ ] **Commit 1**: `feat(attendance): create AttendanceViewModel with cached status counts`

- [ ] Refactor `MarkAttendanceScreen` to be ViewModel-driven
- [ ] **Commit 2**: `refactor(attendance): replace StatefulWidget with ViewModel-driven screen`

- [ ] **PR 3.2 opened** → target `abhishek`
- [ ] PR merged

---

### PR 3.3 — AdminViewModel

**Status**: ⬜ Not started

#### Tasks

- [ ] Create `AdminViewModel extends ChangeNotifier` for shared state (years, classes, teachers, selectedYear, selectedTabIndex)
  - [ ] `loadSharedData()`
  - [ ] `selectYear(AcademicYear year)`
  - [ ] `selectTab(int index)`
- [ ] **Commit 1**: `feat(admin): create AdminDashboardViewModel for shared admin state`

- [ ] Create `AnalyticsTabViewModel extends ChangeNotifier`:
  - [ ] Debounced `applyFilters(...)` method
  - [ ] Parallel `_loadAnalytics()` internally
  - [ ] Cancels debounce timer in `dispose()`
- [ ] **Commit 2**: `feat(admin): create AnalyticsTabViewModel with parallel loading + debounce`

- [ ] Wire `AdminDashboardScreen` to ViewModels
- [ ] **Commit 3**: `refactor(admin): wire AdminDashboardScreen to AdminViewModel`

- [ ] **PR 3.3 opened** → target `abhishek`
- [ ] PR merged

---

## PHASE 4 — Repository Layer + Typed Models

> **Branch**: new `feat/repository` from `abhishek`
> **Goal**: Type-safe API returns, testable repositories, in-memory TTL cache
> **Status**: ⬜ Not started

---

### PR 4.1 — json_serializable Models

**Status**: ⬜ Not started

#### Tasks

- [ ] Add to `pubspec.yaml`:
  - [ ] `json_annotation: ^4.x` under `dependencies`
  - [ ] `build_runner: ^2.x` under `dev_dependencies`
  - [ ] `json_serializable: ^6.x` under `dev_dependencies`
- [ ] **Commit 1**: `chore(models): add json_serializable, json_annotation, build_runner dependencies`

- [ ] Annotate `User` model with `@JsonSerializable(fieldRename: FieldRename.snake)` + `part 'app_models.g.dart'`
- [ ] **Commit 2**: `refactor(models): annotate User model with @JsonSerializable`

- [ ] Annotate all remaining models: `SchoolClass`, `AcademicYear`, `AttendanceSession`, `RosterEntry`, `ClassSummary`, `Defaulter`, `Student`, `Teacher`, `WeeklyDaySchedule`, `SchoolHoliday`
- [ ] **Commit 3**: `refactor(models): annotate all remaining models with @JsonSerializable`

- [ ] Run `dart run build_runner build --delete-conflicting-outputs`
- [ ] **Commit 4**: `chore(models): run build_runner to generate .g.dart serialization files`

- [ ] Update `ApiService` return types from `dynamic` to typed models
- [ ] **Commit 5**: `refactor(api): update ApiService methods to return typed models`

- [ ] **PR 4.1 opened** → target `abhishek`
- [ ] PR merged

---

### PR 4.2 — Repository Pattern

**Status**: ⬜ Not started

#### New files

```
lib/core/
├── result.dart         ← sealed class Result<T> { Success | Failure }
└── app_error.dart      ← AppError domain type

lib/repositories/
├── attendance_repository.dart
├── attendance_repository_impl.dart
├── analytics_repository.dart
├── analytics_repository_impl.dart
├── class_repository.dart
├── class_repository_impl.dart
├── auth_repository.dart
└── auth_repository_impl.dart
```

#### Tasks

- [ ] Create `lib/core/result.dart` — `sealed class Result<T>` with `Success<T>` and `Failure<T>` + `when()` extension
- [ ] **Commit 1**: `feat(core): add Result<T> type for typed error propagation`

- [ ] Create `lib/core/app_error.dart` — `AppError` with `fromApiException()`, static `timeout`, `unknown`
- [ ] **Commit 2**: `feat(core): add AppError domain error type`

- [ ] Create `AttendanceRepository` abstract interface + `AttendanceRepositoryImpl` with TTL cache
- [ ] **Commit 3**: `feat(repositories): add abstract AttendanceRepository interface`
- [ ] **Commit 4**: `feat(repositories): implement AttendanceRepositoryImpl with in-memory TTL cache`

- [ ] Create `AnalyticsRepository`, `ClassRepository`, `AuthRepository` interfaces + impls
- [ ] **Commit 5**: `feat(repositories): add AnalyticsRepository, ClassRepository, AuthRepository`

- [ ] Update `TeacherViewModel` to use injected repositories instead of `ApiService`
- [ ] **Commit 6**: `refactor(teacher): inject AttendanceRepository + ClassRepository into TeacherViewModel`

- [ ] Update Admin ViewModels similarly
- [ ] **Commit 7**: `refactor(admin): inject repositories into AdminViewModel and tab ViewModels`

- [ ] Clear cache in `AuthRepository.logout()`
- [ ] **PR 4.2 opened** → target `abhishek`
- [ ] PR merged

---

## PHASE 5 — Navigation + Offline Readiness

> **Branch**: new `feat/navigation` from `abhishek`
> **Goal**: GoRouter for web URL support + connectivity detection
> **Status**: ⬜ Not started

---

### PR 5.1 — GoRouter Navigation

**Status**: ⬜ Not started

#### Tasks

- [ ] Add `go_router: ^14.x` to `pubspec.yaml`
- [ ] **Commit 1**: `chore(nav): add go_router dependency`

- [ ] Create `lib/core/router/app_router.dart`:
  - [ ] Routes: `/login`, `/admin`, `/admin/sessions/:sessionId/attendance`, `/teacher`, `/teacher/attendance/:sessionId`
  - [ ] `redirect:` guard — unauthenticated → `/login`, authenticated on `/login` → correct dashboard
  - [ ] `refreshListenable: authProvider`
- [ ] **Commit 2**: `feat(nav): implement AppRouter with auth redirect guard`

- [ ] Update `main.dart`: replace `MaterialApp(home: AuthGate())` with `MaterialApp.router(routerConfig: router)`
- [ ] **Commit 3**: `refactor(main): replace MaterialApp with MaterialApp.router + GoRouter`

- [ ] Replace all `Navigator.of(context).push(...)` with `context.go(...)` / `context.push(...)`
- [ ] **Commit 4**: `refactor(screens): replace Navigator.push with context.go / context.push`

- [ ] Test: browser back button, direct URL access, auth redirect
- [ ] **PR 5.1 opened** → target `abhishek`
- [ ] PR merged

---

### PR 5.2 — Offline Detection + Banner

**Status**: ⬜ Not started

#### Tasks

- [ ] Add `connectivity_plus: ^6.x` to `pubspec.yaml`
- [ ] **Commit 1**: `chore(offline): add connectivity_plus dependency`

- [ ] Create `lib/core/connectivity_service.dart` with `ValueNotifier<bool> isOnline`
- [ ] Call `ConnectivityService.instance.init()` in `main()` before `runApp()`
- [ ] **Commit 2**: `feat(core): add ConnectivityService to monitor network state`

- [ ] Create `lib/shared/widgets/offline_banner.dart` using `ValueListenableBuilder` + `AnimatedCrossFade`
- [ ] **Commit 3**: `feat(widgets): add OfflineBanner widget for network-aware screens`

- [ ] Wrap teacher and admin dashboard bodies with `OfflineBanner`
- [ ] **Commit 4**: `feat(screens): wrap teacher and admin dashboards with OfflineBanner`

- [ ] **PR 5.2 opened** → target `abhishek`
- [ ] PR merged

---

## PHASE 6 — Adaptive Responsive Layout

> **Branch**: new `feat/adaptive-layout` from `abhishek`
> **Goal**: Separate Mobile + Desktop widget trees per screen via `ResponsiveLayout`
> **Status**: ⬜ Not started
> **Key rule**: NO `if (isWide)` branches inside view widgets. Use `ResponsiveLayout` only.
> **Depends on**: Phase 3 (ViewModels must exist)

---

### PR 6.1 — Responsive Layout System

**Status**: ⬜ Not started

#### Tasks

- [ ] Create `lib/core/layout/responsive_layout.dart`:
  - [ ] `ResponsiveLayout` — uses `LayoutBuilder`, renders `mobile` or `desktop` subtree
  - [ ] `AdaptiveBuilder` — builder pattern for trivial in-widget decisions only
- [ ] **Commit 1**: `feat(core): add ResponsiveLayout and AdaptiveBuilder widgets`

- [ ] Add responsive/layout constants to `AppConstants`:
  - [ ] `kExpandedNavBreakpoint`, `kNavRailWidth`, `kNavDrawerWidth`
  - [ ] `kDesktopDialogMaxWidth`, `kDesktopContentMaxWidth`
  - [ ] `kBottomNavHeight`, `kMinTapTarget`
  - [ ] `kMobilePadding`, `kDesktopPadding`
- [ ] **Commit 2**: `feat(core): add layout constants to AppConstants`

- [ ] Create `lib/core/layout/adaptive_scaffold.dart`:
  - [ ] `AdaptiveScaffold` with `destinations`, `selectedIndex`, `onDestinationSelected`, `body`
  - [ ] `_MobileScaffold` — `BottomNavigationBar` + compact `AppBar`
  - [ ] `_DesktopScaffold` — `NavigationRail`/`NavigationDrawer` + max-width content
  - [ ] `AdaptiveDestination` immutable data class
- [ ] **Commit 3**: `feat(core): add AdaptiveScaffold for unified mobile/desktop shell`

- [ ] Test: resize browser from 375 → 1400dp, layout switches at exactly 768dp
- [ ] **PR 6.1 opened** → target `abhishek`
- [ ] PR merged

---

### PR 6.2 — Login Screen Adaptive Layout

**Status**: ⬜ Not started

#### Tasks

- [ ] Create `lib/features/auth/views/mobile_login_view.dart` — single column, `SingleChildScrollView`
- [ ] **Commit 1**: `feat(auth): add LoginScreen mobile layout (MobileLoginView)`

- [ ] Create `lib/features/auth/views/desktop_login_view.dart` — two-column split (`Row` flex 2:3)
- [ ] **Commit 2**: `feat(auth): add LoginScreen desktop layout (DesktopLoginView)`

- [ ] Wire `LoginScreen.build()` → `ResponsiveLayout(mobile: MobileLoginView, desktop: DesktopLoginView)`
- [ ] **Commit 3**: `refactor(auth): wire LoginScreen through ResponsiveLayout`

- [ ] Test: 375dp (mobile column), 1280dp (two-column split)
- [ ] **PR 6.2 opened** → target `abhishek`
- [ ] PR merged

---

### PR 6.3 — Teacher Dashboard Adaptive Layout

**Status**: ⬜ Not started

#### Tasks

- [ ] Create `lib/features/teacher/views/mobile_teacher_view.dart`:
  - [ ] Single scroll column: header → controls → session card → KPIs → monthly register → defaulters
  - [ ] `RefreshIndicator` wrapping `SingleChildScrollView`
  - [ ] Student profile → `showModalBottomSheet` (full-screen)
  - [ ] Date → `showDatePicker` modal
- [ ] **Commit 1**: `feat(teacher): implement MobileTeacherView with touch-first layout`

- [ ] Create `lib/features/teacher/views/desktop_teacher_view.dart`:
  - [ ] `Row`: sidebar (280dp fixed) + `VerticalDivider` + `Expanded` main panel
  - [ ] Sidebar: class dropdown + inline `CalendarDatePicker` + quick stats
  - [ ] Main panel: attendance card + KPI row (4 wide) + full monthly register + defaulters `DataTable`
  - [ ] Student profile → `showDialog` (max 520dp)
- [ ] **Commit 2**: `feat(teacher): implement DesktopTeacherView with sidebar + main panel layout`

- [ ] Wire `_TeacherDashboardView.build()` → `ResponsiveLayout`
- [ ] **Commit 3**: `refactor(teacher): wire TeacherDashboardScreen through ResponsiveLayout`

- [ ] Test both layouts end-to-end (class switch, date change, session open/close)
- [ ] **PR 6.3 opened** → target `abhishek`
- [ ] PR merged

---

### PR 6.4 — Admin Dashboard Adaptive Layout

**Status**: ⬜ Not started

#### Tasks

- [ ] Create `lib/features/admin/views/mobile_admin_view.dart`:
  - [ ] `Scaffold` with `AppBar` + `Drawer` (hamburger menu)
  - [ ] `_AdminMobileDrawer` lists all 7 tabs with icons + labels
  - [ ] Full-screen tab body per selection
- [ ] **Commit 1**: `feat(admin): implement MobileAdminView with Drawer navigation`

- [ ] Create `lib/features/admin/views/desktop_admin_view.dart`:
  - [ ] `Row`: `NavigationRail` (collapsed < 1200dp, extended >= 1200dp) + content
  - [ ] `ConstrainedBox(maxWidth: kDesktopContentMaxWidth)` around content
- [ ] **Commit 2**: `feat(admin): implement DesktopAdminView with NavigationRail`

- [ ] For each of the 7 tabs, create `mobile_*_tab.dart` + `desktop_*_tab.dart`:
  - [ ] `analytics_tab` — mobile: stacked charts; desktop: side-by-side charts + sortable DataTable
  - [ ] `sessions_tab` — mobile: card list; desktop: DataTable
  - [ ] `classes_tab` — mobile: card list; desktop: DataTable + inline form panel
  - [ ] `teachers_tab` — mobile: card list; desktop: DataTable + inline form panel
  - [ ] `students_tab` — mobile: card list; desktop: DataTable
  - [ ] `reports_tab` — both similar, minor layout difference
  - [ ] `school_days_tab` — mobile: list; desktop: calendar grid
- [ ] **Commit 3**: `feat(admin): implement adaptive variants for each of the 7 tab content widgets`

- [ ] Wire `_AdminDashboardView.build()` → `ResponsiveLayout`
- [ ] **Commit 4**: `refactor(admin): wire AdminDashboardScreen through ResponsiveLayout`

- [ ] Test: mobile Drawer, desktop rail, 1400dp expanded drawer
- [ ] **PR 6.4 opened** → target `abhishek`
- [ ] PR merged

---

### PR 6.5 — Mark Attendance Adaptive Layout

**Status**: ⬜ Not started

#### Tasks

- [ ] Create `lib/features/attendance/views/mobile_attendance_view.dart`:
  - [ ] `SearchableDropdown` for status per row
  - [ ] Status counters as scrollable `Chip` row
  - [ ] Bulk action via `PopupMenuButton` in `AppBar`
  - [ ] Save → fixed bottom `ElevatedButton`
- [ ] **Commit 1**: `feat(attendance): implement MobileAttendanceView with touch-optimised roster`

- [ ] Create `lib/features/attendance/views/desktop_attendance_view.dart`:
  - [ ] 4 `ChoiceChip` buttons inline per roster row
  - [ ] Status counters as 4-column grid header
  - [ ] Bulk action as inline button row above list
  - [ ] Search in 280dp sticky sidebar
- [ ] **Commit 2**: `feat(attendance): implement DesktopAttendanceView with inline chip controls`

- [ ] Wire `MarkAttendanceScreen.build()` → `ResponsiveLayout`
- [ ] **Commit 3**: `refactor(attendance): wire MarkAttendanceScreen through ResponsiveLayout`

- [ ] **PR 6.5 opened** → target `abhishek`
- [ ] PR merged

---

## Cross-Cutting Tasks (All Phases)

These apply across all phases and must be checked on every PR:

- [ ] `dart analyze` — zero errors before every PR
- [ ] `dart format lib/` — run before every commit
- [ ] `dart fix --apply` — run on every PR
- [ ] No `print()` statements anywhere — use `AppLogger`
- [ ] No bare `dynamic` in new code
- [ ] All new strings use single quotes
- [ ] All imports use `package:attendance_app/...` (not relative `../`)
- [ ] All new `StatelessWidget` constructors use `const`
- [ ] All new build methods < 50 lines (delegate to smaller widgets)
- [ ] No `BuildContext` in ViewModel classes
- [ ] Every `Timer` cancelled in `dispose()`
- [ ] Every `TextEditingController` / `FocusNode` / `ScrollController` disposed

---

## Device Test Matrix (Phase 6)

| Device | Width | Layout | Status |
|---|---|---|---|
| iPhone SE | 375dp | Mobile | ⬜ |
| iPhone 14 Pro | 393dp | Mobile | ⬜ |
| iPad Mini portrait | 744dp | Desktop | ⬜ |
| MacBook 13" | 1280dp | Desktop (collapsed rail) | ⬜ |
| MacBook 16" | 1536dp | Desktop (expanded drawer) | ⬜ |

---

## Known Issues / Decisions Pending

| Issue | Decision | Status |
|---|---|---|
| Admin mobile nav: Drawer vs BottomNavBar | Using Drawer (7 tabs too many for bottom bar) — revisit after user testing | Decided |
| Tablet (744dp) uses Desktop layout | Confirmed — tablet benefits from nav rail | Decided |
| Monthly register grid virtualisation | Deferred to Phase 6 — use `SliverGrid` on mobile | Deferred |
| Skeleton/shimmer loading screens | Deferred — add after MVVM is complete | Deferred |
| Certificate pinning | Low priority — deferred post-launch | Deferred |
| Unit tests | Start in Phase 3 alongside ViewModel creation | Planned |
