import 'package:flutter/material.dart';
import '../../../../design_system/app_breakpoints.dart';
import '../../../../providers/app_providers.dart';
import '../../../../shared/widgets/app_vertical_navbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminNavigation extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final String? userFullName;
  final VoidCallback? onRefreshTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLogoutTap;

  const AdminNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.userFullName,
    this.onRefreshTap,
    this.onProfileTap,
    this.onLogoutTap,
  });

  // 8 tabs: Overview(0) + 7 existing (shifted +1)
  static const List<VerticalNavDestination> navDestinations = [
    VerticalNavDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Overview',
    ),
    VerticalNavDestination(
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today_rounded,
      label: 'Sessions',
    ),
    VerticalNavDestination(
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics_rounded,
      label: 'Analytics',
    ),
    VerticalNavDestination(
      icon: Icons.class_outlined,
      selectedIcon: Icons.class_rounded,
      label: 'Classes',
    ),
    VerticalNavDestination(
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      label: 'Students',
    ),
    VerticalNavDestination(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Teachers',
    ),
    VerticalNavDestination(
      icon: Icons.assessment_outlined,
      selectedIcon: Icons.assessment_rounded,
      label: 'Reports',
    ),
    VerticalNavDestination(
      icon: Icons.date_range_outlined,
      selectedIcon: Icons.date_range_rounded,
      label: 'School Days',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    if (context.isMobile) {
      return _buildMobileNavigation(context, ref, isDark);
    }
    return _buildDesktopNavigation(context, ref);
  }

  Widget _buildMobileNavigation(BuildContext context, WidgetRef ref, bool isDark) {
    // Mobile bottom bar shows 5: Overview, Sessions, Analytics, Classes, More
    const primaryCount = 4;
    final primaryDestinations = navDestinations.take(primaryCount).toList();
    final bool isMoreSelected = selectedIndex >= primaryCount;
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      body: body,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF4F46E5)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.school, color: Colors.white, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'Admin Portal',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (userFullName != null)
                    Text(
                      userFullName!,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                ],
              ),
            ),
            ...List.generate(navDestinations.length, (i) {
              final d = navDestinations[i];
              return ListTile(
                leading: Icon(
                  selectedIndex == i ? (d.selectedIcon ?? d.icon) : d.icon,
                  color: selectedIndex == i ? const Color(0xFF4F46E5) : null,
                ),
                title: Text(
                  d.label,
                  style: TextStyle(
                    color: selectedIndex == i ? const Color(0xFF4F46E5) : null,
                    fontWeight: selectedIndex == i ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: selectedIndex == i,
                selectedTileColor: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                onTap: () {
                  Navigator.pop(context);
                  onDestinationSelected(i);
                },
              );
            }),
            const Divider(),
            // Dark mode toggle in drawer
            SwitchListTile(
              secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode_outlined),
              title: const Text('Dark Mode'),
              value: isDark,
              onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
            ),
            if (onLogoutTap != null)
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: onLogoutTap,
              ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: isMoreSelected ? primaryCount : selectedIndex,
        onDestinationSelected: (idx) {
          if (idx == primaryCount) {
            scaffoldKey.currentState?.openDrawer();
          } else {
            onDestinationSelected(idx);
          }
        },
        destinations: [
          ...primaryDestinations.map(
            (d) => NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon ?? d.icon),
              label: d.label,
            ),
          ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopNavigation(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          AppVerticalNavbar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: navDestinations,
            title: 'Admin Portal',
            subtitle: 'School Management',
            userFullName: userFullName,
            userRole: 'Administrator',
            onRefreshTap: onRefreshTap,
            onProfileTap: onProfileTap,
            onLogoutTap: onLogoutTap,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}
