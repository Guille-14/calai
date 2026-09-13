import 'package:flutter/material.dart';
import '../../core/symmetry/symmetry_progression_service.dart';
import '../../core/symmetry/symmetry_rank_system.dart';
import '../../core/symmetry/health_connect_bridge.dart';

class SymmetryHistoryScreen extends StatefulWidget {
  const SymmetryHistoryScreen({super.key});

  @override
  State<SymmetryHistoryScreen> createState() => _SymmetryHistoryScreenState();
}

class _SymmetryHistoryScreenState extends State<SymmetryHistoryScreen> {
  final SymmetryProgressionService _symmetryService =
      SymmetryProgressionService();
  bool _isLoading = true;
  List<WorkoutSession> _workouts = [];
  HealthConnectBridge _healthBridge = HealthConnectBridge();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _symmetryService.initialize();
    if (mounted) {
      setState(() {
        _workouts = _healthBridge.recentWorkouts;
        _isLoading = false;
      });
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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Historial',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _workouts.isEmpty ? _buildEmptyState() : _buildWorkoutList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sin entrenamientos aún',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Completa tu primer entrenamiento\npara ver tu progreso aquí',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutList() {
    final progress = _symmetryService.getProgress();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildStatsSummary(progress),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Entrenamientos recientes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_workouts.length} sesiones',
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildWorkoutCard(_workouts[index]),
            childCount: _workouts.length,
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildStatsSummary(SymmetryProgress progress) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            progress.currentRank.color.withOpacity(0.15),
            progress.currentRank.color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: progress.currentRank.color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, color: progress.currentRank.color, size: 24),
              const SizedBox(width: 8),
              Text(
                progress.currentRank.displayName,
                style: TextStyle(
                  color: progress.currentRank.color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                label: 'Total XP',
                value: '${progress.totalXP.toStringAsFixed(0)}',
                icon: Icons.stars,
              ),
              _buildStatItem(
                label: 'Entrenos',
                value: '${_healthBridge.totalWorkouts}',
                icon: Icons.fitness_center,
              ),
              _buildStatItem(
                label: 'Tonelaje',
                value:
                    '${(_healthBridge.totalTonnage / 1000).toStringAsFixed(1)}t',
                icon: Icons.monitor_weight,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                label: 'Racha',
                value: '${progress.streakDays.toInt()} días',
                icon: Icons.local_fire_department,
              ),
              _buildStatItem(
                label: 'Semanal',
                value: '+${progress.weeklyXP.toStringAsFixed(0)} XP',
                icon: Icons.calendar_today,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white38, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildWorkoutCard(WorkoutSession workout) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(workout.date),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${workout.totalTonnage.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                    color: Color(0xFF00C853),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildWorkoutStat(Icons.fitness_center,
                  '${workout.exercises.length} ejercicios'),
              const SizedBox(width: 16),
              _buildWorkoutStat(Icons.timer, '${workout.durationMinutes} min'),
              const SizedBox(width: 16),
              _buildWorkoutStat(
                Icons.category,
                workout.muscleGroupTonnage.keys.isNotEmpty
                    ? workout.muscleGroupTonnage.keys.first
                    : 'General',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Hoy';
    } else if (diff.inDays == 1) {
      return 'Ayer';
    } else if (diff.inDays < 7) {
      return 'Hace ${diff.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
