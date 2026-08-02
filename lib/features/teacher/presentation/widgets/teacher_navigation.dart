import 'package:flutter/material.dart';
import '../../../../design_system/app_breakpoints.dart';
import '../../../../shared/widgets/app_vertical_navbar.dart';

class TeacherNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final String? userFullName;
  final VoidCallback? onProfileTap;
  final VoidCallback? onRefreshTap;
  final VoidCallback? onLogoutTap;

  const TeacherNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.userFullName,
    this.onProfileTap,
    this.onRefreshTap,
    this.onLogoutTap,
  });

  static const List<VerticalNavDestination> destinations = [
    VerticalNavDestination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      label: 'Workstation',
    ),
    VerticalNavDestination(
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
      label: 'Attendance Register',
    ),
    VerticalNavDestination(
      icon: Icons.warning_amber_rounded,
      selectedIcon: Icons.warning_rounded,
      label: 'Defaulters Deck',
    ),
    VerticalNavDestination(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile & Security',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) {
      return _buildMobileLayout(context);
    }
    return _buildDesktopLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
    final mobileLabels = ['Workstation', 'Register', 'Defaulters', 'Profile'];

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        height: 62,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        //  labelBehavior: NavigationBarDestinationLabelBehavior.alwaysShow,
        destinations: List.generate(destinations.length, (i) {
          final d = destinations[i];
          return NavigationDestination(
            icon: Icon(d.icon, size: 20),
            selectedIcon: Icon(d.selectedIcon ?? d.icon, size: 22),
            label: mobileLabels[i],
          );
        }),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AppVerticalNavbar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: destinations,
            title: 'Teacher Portal',
            subtitle: 'Attendance Station',
            userFullName: userFullName,
            userRole: 'Teacher',
            onProfileTap: onProfileTap,
            onRefreshTap: onRefreshTap,
            onLogoutTap: onLogoutTap,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}
