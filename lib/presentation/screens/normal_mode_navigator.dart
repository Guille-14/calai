import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_constants.dart';
import 'home_screen.dart';
import 'scan_food_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

class NormalModeNavigator extends StatefulWidget {
  final VoidCallback onEnterSymmetry;

  const NormalModeNavigator({super.key, required this.onEnterSymmetry});

  @override
  State<NormalModeNavigator> createState() => _NormalModeNavigatorState();
}

class _NormalModeNavigatorState extends State<NormalModeNavigator> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    ScanFoodScreen(),
    ProgressScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildNavBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: widget.onEnterSymmetry,
        backgroundColor: const Color(0xFF00C853),
        child: const Icon(Icons.fitness_center, color: Colors.black),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildNavBar() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavBarItem(
                icon: Icons.grid_view_rounded,
                label: 'INICIO',
                isSelected: _currentIndex == 0,
                onTap: () => _onNavTap(0),
              ),
              _NavBarItem(
                icon: Icons.camera_alt_outlined,
                label: 'ESCANEAR',
                isSelected: _currentIndex == 1,
                onTap: () => _onNavTap(1),
              ),
              const SizedBox(width: 56),
              _NavBarItem(
                icon: Icons.trending_up_rounded,
                label: 'PROGRESO',
                isSelected: _currentIndex == 2,
                onTap: () => _onNavTap(2),
              ),
              _NavBarItem(
                icon: Icons.settings_outlined,
                label: 'AJUSTES',
                isSelected: _currentIndex == 3,
                onTap: () => _onNavTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onNavTap(int index) {
    if (index != _currentIndex) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentIndex = index;
      });
    }
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          border: isSelected
              ? Border.all(color: AppColors.accentCalories, width: 1.5)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20,
                color: isSelected ? AppColors.accentCalories : Colors.white38),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.accentCalories : Colors.white24,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
