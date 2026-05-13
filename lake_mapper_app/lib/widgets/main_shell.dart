import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../theme/app_colors.dart';
import '../screens/home_screen.dart';
import '../screens/map_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/export_screen.dart';
import '../screens/settings_screen.dart';
// Web: iframe-basierte Karte (kein WebGL nötig)
import '../screens/map_screen_web.dart' if (dart.library.io) '../screens/map_screen_stub.dart'
    as map_web;

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  List<Widget> get _screens => [
    const HomeScreen(),
    kIsWeb ? const map_web.MapScreenWeb() : const MapScreen(),
    const StatisticsScreen(),
    const ExportScreen(),
    const SettingsScreen(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(Icons.water_drop_outlined, Icons.water_drop, 'Messung'),
    _NavItem(Icons.map_outlined, Icons.map, 'Karte'),
    _NavItem(Icons.bar_chart_outlined, Icons.bar_chart, 'Stats'),
    _NavItem(Icons.download_outlined, Icons.download, 'Export'),
    _NavItem(Icons.settings_outlined, Icons.settings, 'Setup'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.navyDark,
          border: Border(
            top: BorderSide(
              color: AppColors.cyan.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.abyss.withValues(alpha: 0.8),
              blurRadius: 24,
              spreadRadius: 4,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isActive = index == _currentIndex;
                return _buildNavItem(item, isActive, () {
                  setState(() => _currentIndex = index);
                });
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: isActive
            ? BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.cyan.withValues(alpha: 0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.withValues(alpha: 0.12),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              size: 22,
              color: isActive ? AppColors.cyan : AppColors.steelBlue,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.3,
                color: isActive
                    ? AppColors.cyan.withValues(alpha: 0.9)
                    : AppColors.steelBlue.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem(this.icon, this.activeIcon, this.label);
}
