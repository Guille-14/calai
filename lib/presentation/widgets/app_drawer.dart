import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../screens/recipe_home_screen.dart';
import '../screens/symmetry_navigator.dart';
import '../screens/scan_food_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: AppColors.background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.background,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: colors.primary.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.fitness_center,
                    color: colors.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'CalAI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.home, color: colors.primary),
            title: const Text('Inicio', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.fitness_center, color: colors.secondary),
            title: const Text('Modo HEAVY', style: TextStyle(color: Colors.white)),
            onTap: () {
              // Entrada directa al modo HEAVY real (SymmetryNavigator).
              // Antes abría SymmetryDashboardScreen, un cluster con imports
              // rotos que impedía compilar la app.
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SymmetryNavigator(
                    onExitSymmetry: () => Navigator.pop(context),
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.menu_book, color: colors.secondary),
            title: const Text('Recetas', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecipeHomeScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.camera_alt, color: colors.secondary),
            title: const Text('Escanear Comida', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              // Usa ScanFoodScreen (la pantalla de escaneo de la navegación
              // principal). Antes apuntaba a FoodScannerScreen, una segunda
              // implementación duplicada que se eliminó.
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanFoodScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
