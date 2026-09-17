import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../screens/recipe_home_screen.dart';
import '../screens/scan_food_screen.dart';
import '../screens/symmetry_history_screen.dart';
import '../screens/symmetry_ranks_screen.dart';
import '../screens/openrouter_diagnostics_screen.dart';

/// Drawer lateral (solo pantalla de Inicio).
///
/// La fusión eliminó "Modo HEAVY" (SymmetryNavigator): el entrenamiento ya
/// es la pestaña "Entrenar" del MainNavigator, no un modo aparte. El drawer
/// conserva las entradas secundarias reales: recetas, escaneo y las
/// pantallas de entrenamiento que no tienen pestaña propia (historial y
/// rangos) más el diagnóstico de IA.
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
            title:
                const Text('Escanear Comida', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              // ScanFoodScreen es la misma pantalla que la pestaña
              // "Escanear" del MainNavigator.
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanFoodScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.history, color: colors.secondary),
            title: const Text('Historial de entrenamientos',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SymmetryHistoryScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.emoji_events, color: colors.secondary),
            title: const Text('Rangos', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SymmetryRanksScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.psychology, color: colors.secondary),
            title: const Text('Diagnóstico IA', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const OpenRouterDiagnosticsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
