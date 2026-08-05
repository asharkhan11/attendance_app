# Performance Baseline (Pre-Refactor)

> Recorded on: 2026-07-31
> Environment: Flutter Web / Android Emulator Target

## Pre-Refactor Architectural & Performance Snapshot

| Metric / Aspect | Pre-Refactor Baseline | Target (Post-Refactor) |
|---|---|---|
| Code Architecture | Single monolithic 5873-line file (`admin_dashboard.dart`) | Modular feature-first Clean Architecture (`presentation`, `domain`, `data`) |
| State Management | Direct `setState` logic bloat inside StatefulWidgets | Riverpod `AsyncNotifier` / `StateNotifier` |
| Navigation UI | 7 items crammed in mobile BottomNav | 5 items + NavigationDrawer on mobile / NavigationRail on desktop |
| Mobile Layout Grid | 30+ column `DataTable` (horizontally overflowing) | Responsive `SliverList` with `MonthlyGridStudentCard` |
| List Virtualization | Basic `ListView` without fixed `itemExtent` | `SliverFixedExtentList` with `kListCacheExtent` |
| Render Rebuilds | Full widget tree rebuilds on every `setState` | Scoped Riverpod `select()` slice updates |
| Network / Data Layer | Direct HTTP calls in UI widgets via `ApiService` | Repository + Datasource + DTO Mapper pipeline |
