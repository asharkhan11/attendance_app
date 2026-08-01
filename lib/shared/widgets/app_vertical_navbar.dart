import 'package:flutter/material.dart';
import '../../design_system/app_breakpoints.dart';
import '../../design_system/app_radius.dart';
import '../../design_system/app_spacing.dart';

class VerticalNavDestination {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final String? badge;

  const VerticalNavDestination({
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.badge,
  });
}

class AppVerticalNavbar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<VerticalNavDestination> destinations;
  final String title;
  final String? subtitle;
  final String? userFullName;
  final String? userRole;
  final VoidCallback? onProfileTap;
  final VoidCallback? onRefreshTap;
  final VoidCallback? onLogoutTap;

  const AppVerticalNavbar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.title,
    this.subtitle,
    this.userFullName,
    this.userRole,
    this.onProfileTap,
    this.onRefreshTap,
    this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpanded = context.isDesktop;

    return Container(
      width: isExpanded ? 240.0 : 72.0,
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          // Header Branding
          _buildHeader(context, isExpanded),
          const Divider(height: 1, thickness: 1),

          // Navigation Destinations
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final d = destinations[index];
                final isSelected = index == selectedIndex;
                return _buildNavItem(context, d, index, isSelected, isExpanded);
              },
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Footer User Profile & Actions
          _buildFooter(context, isExpanded),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isExpanded) {
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      height: 72,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.school, color: primaryColor, size: 24),
          ),
          if (isExpanded) ...[
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    VerticalNavDestination dest,
    int index,
    bool isSelected,
    bool isExpanded,
  ) {
    final theme = Theme.of(context);
    final activeColor = theme.primaryColor;

    if (!isExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Tooltip(
          message: dest.label,
          preferBelow: false,
          child: InkWell(
            onTap: () => onDestinationSelected(index),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Center(
                child: Icon(
                  isSelected ? (dest.selectedIcon ?? dest.icon) : dest.icon,
                  color: isSelected ? activeColor : Colors.grey.shade700,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2.0),
      child: InkWell(
        onTap: () => onDestinationSelected(index),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10.0),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: isSelected
                ? Border(left: BorderSide(color: activeColor, width: 3))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? (dest.selectedIcon ?? dest.icon) : dest.icon,
                color: isSelected ? activeColor : Colors.grey.shade700,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  dest.label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                    color: isSelected ? activeColor : Colors.grey.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (dest.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    dest.badge!,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isExpanded) {
    final theme = Theme.of(context);
    final user = userFullName ?? 'User';
    final initial = user.isNotEmpty ? user[0].toUpperCase() : 'U';

    if (!isExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            if (onRefreshTap != null)
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: onRefreshTap,
                tooltip: 'Refresh',
              ),
            if (onProfileTap != null)
              IconButton(
                icon: const Icon(Icons.person_outline, size: 20),
                onPressed: onProfileTap,
                tooltip: 'Profile',
              ),
            if (onLogoutTap != null)
              IconButton(
                icon: const Icon(Icons.logout, size: 20),
                onPressed: onLogoutTap,
                tooltip: 'Logout',
              ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.primaryColor.withValues(alpha: 0.2),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (userRole != null)
                      Text(
                        userRole!,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (onProfileTap != null)
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  onPressed: onProfileTap,
                  tooltip: 'Profile Settings',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (onRefreshTap != null)
                TextButton.icon(
                  onPressed: onRefreshTap,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Refresh', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              if (onLogoutTap != null)
                TextButton.icon(
                  onPressed: onLogoutTap,
                  icon: const Icon(Icons.logout, size: 14, color: Colors.redAccent),
                  label: const Text('Logout', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
