import 'package:flutter/material.dart';
import '../../../../design_system/app_breakpoints.dart';

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

  static const List<({IconData icon, String label})> destinations = [
    (icon: Icons.calendar_today, label: 'Sessions'),
    (icon: Icons.analytics, label: 'Analytics'),
    (icon: Icons.class_, label: 'Classes'),
    (icon: Icons.people, label: 'Students'),
    (icon: Icons.person, label: 'Teachers'),
    (icon: Icons.assessment, label: 'Reports'),
    (icon: Icons.date_range, label: 'School Days'),
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
    final primaryDestinations = destinations.take(4).toList();
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
            ...List.generate(destinations.length, (i) {
              final d = destinations[i];
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
          NavigationRail(
            extended: context.isDesktop,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: context.isDesktop
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.selected,
            destinations: destinations
                .map(
                  (d) => NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}
