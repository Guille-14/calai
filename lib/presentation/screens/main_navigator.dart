import 'package:flutter/foundation.dart';
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
/// Las pestañas se montan bajo demanda y el IndexedStack conserva el estado
/// de las que ya se visitaron (no se reconstruye una pantalla al cambiar de
/// pestaña).
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

    // Instrumentación ligera para comprobar en debug que el primer frame no
    // monta Perfil, Progreso, Entrenar ni Escanear por adelantado.
    final startup = Stopwatch()..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      startup.stop();
      final mountedTabs = _screens.whereType<Widget>().length;
      debugPrint(
        'MainNavigator: primer frame interactivo en '
        '${startup.elapsedMilliseconds}ms; pestañas montadas: '
        '$mountedTabs/5',
      );
    });
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
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: _selectTab,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Inicio',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.qr_code_scanner_outlined),
                    selectedIcon: Icon(Icons.qr_code_scanner_rounded),
                    label: 'Escanear',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.fitness_center_outlined),
                    selectedIcon: Icon(Icons.fitness_center),
                    label: 'Entrenar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.insights_outlined),
                    selectedIcon: Icon(Icons.insights_rounded),
                    label: 'Progreso',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outlined),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'Perfil',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
