import 'package:flutter/material.dart';
import '../../core/symmetry/symmetry_progression_service.dart';
import '../../core/symmetry/symmetry_rank_system.dart';
import '../../core/symmetry/macro_bridge.dart';

class SymmetryProfileScreen extends StatefulWidget {
  const SymmetryProfileScreen({super.key});

  @override
  State<SymmetryProfileScreen> createState() => _SymmetryProfileScreenState();
}

class _SymmetryProfileScreenState extends State<SymmetryProfileScreen> {
  final SymmetryProgressionService _symmetryService =
      SymmetryProgressionService();
  final MacroBridge _macroBridge = MacroBridge();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _symmetryService.initialize();
    await _macroBridge.initialize();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final progress = _symmetryService.getProgress();
    final heatMap = _symmetryService.getMuscleHeatMap();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Perfil',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildRankCard(progress),
            const SizedBox(height: 20),
            _buildProteinCard(),
            const SizedBox(height: 20),
            _buildHeatMapCard(heatMap),
            const SizedBox(height: 20),
            _buildSettingsCard(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildRankCard(SymmetryProgress progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            progress.currentRank.color.withValues(alpha: 0.2),
            progress.currentRank.color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: progress.currentRank.color.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  progress.currentRank.color,
                  progress.currentRank.color.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: progress.currentRank.color.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.shield,
                color: Colors.white,
                size: 50,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            progress.currentRank.displayName,
            style: TextStyle(
              color: progress.currentRank.color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nivel ${progress.currentRank.level}',
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: progress.rankProgress,
            color: progress.currentRank.color,
            backgroundColor: Colors.white12,
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.totalXP.toStringAsFixed(0)} XP',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (progress.currentRank.nextRank != null)
                Text(
                  '${progress.currentRank.nextRank!.displayName}',
                  style: TextStyle(
                    color: progress.currentRank.nextRank!.color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProteinCard() {
    final proteinGoal = _macroBridge.proteinGoal;
    final currentProtein = _macroBridge.dailyProtein;
    final progress = _macroBridge.proteinProgress;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restaurant,
                  color: Color(0xFF00C853),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Meta de Proteína',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (_macroBridge.metProteinGoal)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'x1.2',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${currentProtein.toStringAsFixed(0)}g',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '/ ${proteinGoal.toStringAsFixed(0)}g',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            color: _macroBridge.metProteinGoal
                ? const Color(0xFF00C853)
                : const Color(0xFFFFD700),
            backgroundColor: Colors.white12,
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            _macroBridge.getProteinStatusMessage(),
            style: TextStyle(
              color: _macroBridge.metProteinGoal
                  ? const Color(0xFF00C853)
                  : Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatMapCard(Map<String, double> heatMap) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.map, color: Color(0xFFFF6B6B)),
              SizedBox(width: 8),
              Text(
                'Estado Muscular',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (heatMap.isEmpty)
            const Text(
              'Completa entrenamientos para ver el estado muscular',
              style: TextStyle(color: Colors.white54),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: heatMap.entries.map((entry) {
                final color = _getFatigueColor(entry.value);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.key,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Color _getFatigueColor(double fatigue) {
    if (fatigue < 30) return Colors.green;
    if (fatigue < 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configuración',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingsItem(
            icon: Icons.restaurant,
            title: 'Objetivo de proteína',
            subtitle: '${_macroBridge.proteinGoal.toInt()}g diarios',
            onTap: () => _showProteinGoalDialog(),
          ),
          const Divider(color: Colors.white12),
          _buildSettingsItem(
            icon: Icons.refresh,
            title: 'Restablecer progreso',
            subtitle: 'Borrar todos los datos de Symmetry',
            onTap: () => _showResetDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
    );
  }

  void _showProteinGoalDialog() {
    final controller = TextEditingController(
      text: _macroBridge.proteinGoal.toInt().toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Objetivo de Proteína',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            suffixText: 'g',
            suffixStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.black,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final goal = double.tryParse(controller.text);
              if (goal != null) {
                _symmetryService.setProteinGoal(goal);
                Navigator.pop(context);
                _loadData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Restablecer progreso?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Esta acción eliminará todo tu progreso de Symmetry, incluyendo XP, rangos e historial.',
          style: TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              _symmetryService.reset();
              Navigator.pop(context);
              _loadData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
  }
}
