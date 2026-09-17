import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'symmetry_workout_screen.dart';
import 'symmetry_history_screen.dart';
import 'symmetry_ranks_screen.dart';
import 'symmetry_profile_screen.dart';

class SymmetryNavigator extends StatefulWidget {
  final VoidCallback onExitSymmetry;

  const SymmetryNavigator({super.key, required this.onExitSymmetry});

  @override
  State<SymmetryNavigator> createState() => _SymmetryNavigatorState();
}

class _SymmetryNavigatorState extends State<SymmetryNavigator> {
  int _currentIndex = 2;

  final List<Widget> _screens = [
    const SymmetryHistoryScreen(),
    const SymmetryRanksScreen(),
    const SymmetryWorkoutScreen(),
    const SymmetryProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => _showExitConfirmation(context),
          tooltip: 'Volver al modo Normal',
        ),
        title: const Text(
          'HEAVY',
          style: TextStyle(
            color: Color(0xFF00C853),
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickActions,
        backgroundColor: const Color(0xFF00C853),
        child: const Icon(Icons.add, color: Colors.black, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
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
                icon: Icons.history,
                label: 'HISTORIAL',
                isSelected: _currentIndex == 0,
                onTap: () => _onNavTap(0),
              ),
              _NavBarItem(
                icon: Icons.shield,
                label: 'RANGOS',
                isSelected: _currentIndex == 1,
                onTap: () => _onNavTap(1),
              ),
              const SizedBox(width: 72),
              _NavBarItem(
                icon: Icons.fitness_center,
                label: 'ENTRENAR',
                isSelected: _currentIndex == 2,
                onTap: () => _onNavTap(2),
              ),
              _NavBarItem(
                icon: Icons.person,
                label: 'PERFIL',
                isSelected: _currentIndex == 3,
                onTap: () => _onNavTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Nuevo entrenamiento',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildActionItem(
                icon: Icons.flash_on,
                label: 'Entrenamiento Rápido',
                subtitle: 'Sesión corta y efectiva',
                onTap: () {
                  Navigator.pop(context);
                  _onNavTap(2);
                },
              ),
              _buildActionItem(
                icon: Icons.fitness_center,
                label: 'Entrenamiento Libre',
                subtitle: 'Añade ejercicios manualmente',
                onTap: () {
                  Navigator.pop(context);
                  _onNavTap(2);
                },
              ),
              _buildActionItem(
                icon: Icons.list_alt,
                label: 'Rutina Guardada',
                subtitle: 'Ejecuta una rutina existente',
                onTap: () {
                  Navigator.pop(context);
                  _onNavTap(0);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        tileColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF00C853).withValues(alpha: 0.15),
          child: Icon(icon, color: const Color(0xFF00C853)),
        ),
        title: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
        onTap: onTap,
      ),
    );
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('¿Salir del modo HEAVY?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Podrás volver a escanear alimentos y acceder a la IA.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onExitSymmetry();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
            ),
            child: const Text('Salir'),
          ),
        ],
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
              ? Border.all(color: const Color(0xFF00C853), width: 1.5)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20,
                color: isSelected ? const Color(0xFF00C853) : Colors.white38),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00C853) : Colors.white24,
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
