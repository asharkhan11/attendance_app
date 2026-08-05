import 'package:flutter/material.dart';
import '../../../../design_system/app_breakpoints.dart';
import '../../../../shared/widgets/app_vertical_navbar.dart';

class AdminNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  const AdminNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
  });

  static const List<VerticalNavDestination> navDestinations = [
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
  Widget build(BuildContext context) {
    if (context.isMobile) {
      return _buildMobileNavigation(context);
    }
    return _buildDesktopNavigation(context);
  }

  Widget _buildMobileNavigation(BuildContext context) {
    // 5 primary items: Sessions, Analytics, Classes, Students, More
    final primaryDestinations = navDestinations.take(4).toList();
    final bool isMoreSelected = selectedIndex >= 4;

    return Scaffold(
      body: body,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF4F46E5)),
              child: Text(
                'Admin Management',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ...List.generate(navDestinations.length, (i) {
              final d = navDestinations[i];
              return ListTile(
                leading: Icon(d.icon),
                title: Text(d.label),
                selected: selectedIndex == i,
                onTap: () {
                  Navigator.pop(context);
                  onDestinationSelected(i);
                },
              );
            }),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: isMoreSelected ? 4 : selectedIndex,
        onDestinationSelected: (idx) {
          if (idx == 4) {
            Scaffold.of(context).openDrawer();
          } else {
            onDestinationSelected(idx);
          }
        },
        destinations: [
          ...primaryDestinations.map(
            (d) => NavigationDestination(icon: Icon(d.icon), label: d.label),
          ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopNavigation(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AppVerticalNavbar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: navDestinations,
            title: 'Admin Portal',
            subtitle: 'School Management',
            userRole: 'Administrator',
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}
