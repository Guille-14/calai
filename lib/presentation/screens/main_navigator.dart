import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'home_screen.dart';
import 'scan_food_screen.dart';
import 'symmetry_workout_screen.dart';
import 'progress_screen.dart';
import 'profile_screen.dart';

/// Navegador único de la app: una sola barra con 5 pestañas.
///
/// Antes de la fusión la app tenía un "switcher de modos"
/// (AppSwitcherScreen) que bifurcaba en dos apps por separado, cada una con
/// su propio navegador (NormalModeNavigator para comida y SymmetryNavigator
/// para entrenamiento), y el usuario tenía que "cambiar de modo" con
/// diálogos de confirmación. Ahora es un solo flujo:
/// Inicio · Escanear · Entrenar · Progreso · Perfil.
///
/// IndexedStack conserva el estado de cada pantalla al cambiar de pestaña
/// (no se reconstruye la pantalla de comida al ir a entrenar, etc.).
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;
  late final List<Widget?> _screens;

  @override
  void initState() {
    super.initState();
    // No montamos las cinco pantallas al arrancar: Perfil y Progreso hacen
    // lecturas de SQLite/Health Connect y antes bloqueaban el primer frame.
    _screens = [const HomeScreen(), null, null, null, null];
  }

  Widget _screenFor(int index) {
    switch (index) {
      case 1:
        return const ScanFoodScreen();
      case 2:
        return const SymmetryWorkoutScreen();
      case 3:
        return const ProgressScreen();
      case 4:
        return const ProfileScreen();
      default:
        return const HomeScreen();
    }
  }

  void _selectTab(int index) {
    if (_screens[index] == null) {
      _screens[index] = _screenFor(index);
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                for (final screen in _screens) screen ?? const SizedBox.shrink(),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.cardBackground,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SafeArea(
              top: false,
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: _currentIndex,
                selectedItemColor: AppColors.accent,
                unselectedItemColor: AppColors.textSecondary,
                selectedLabelStyle: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                onTap: _selectTab,
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.home_outlined), label: 'Inicio'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.qr_code_scanner_outlined),
                      label: 'Escanear'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.fitness_center_outlined),
                      label: 'Entrenar'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.insights_outlined), label: 'Progreso'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.person_outlined), label: 'Perfil'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
