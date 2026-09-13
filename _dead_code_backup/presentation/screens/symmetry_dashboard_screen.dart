import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/strength_ranks_service.dart';
import '../../../data/services/workout_storage.dart';
import '../../../models/rank_system.dart';
import '../../../models/workout_models.dart';
import '../../../models/strength_ranks_model.dart';
import '../widgets/body_map_widget.dart';
import '../widgets/rank_card.dart';

class SymmetryDashboardScreen extends StatefulWidget {
  const SymmetryDashboardScreen({super.key});

  @override
  State<SymmetryDashboardScreen> createState() =>
      _SymmetryDashboardScreenState();
}

class _SymmetryDashboardScreenState extends State<SymmetryDashboardScreen> {
  late StrengthRanksService _ranksService;
  late WorkoutStorageService _workoutService;
  BodyAnalysis? _bodyAnalysis;
  bool _isLoading = true;
  List<Routine> _routines = [];

  @override
  void initState() {
    super.initState();
    _ranksService = StrengthRanksService();
    _workoutService = WorkoutStorageService();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final analysis = await _ranksService.getBodyAnalysis();
      final routines = await _workoutService.getAllRoutines();
      if (mounted) {
        setState(() {
          _bodyAnalysis = analysis;
          _routines = routines;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _bodyAnalysis == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final analysis = _bodyAnalysis!;
    final predictedRank = StrengthRankExtension.fromLevel(analysis.overallLevel);
    final averageProgress = analysis.muscleRanks.isNotEmpty
        ? analysis.muscleRanks.values
                .fold<double>(0, (sum, rank) =>
                    sum + (rank.nextRankXP > 0 ? rank.currentXP / rank.nextRankXP : 0)) /
            analysis.muscleRanks.length
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.background,
            floating: true,
            pinned: true,
            expandedHeight: 90,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Symmetry',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 22,
                ),
              ),
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 12),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_outlined, color: Colors.white70),
                onPressed: _loadData,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _buildSectionTitle(
                'Entrenamientos',
                onTap: () {
                  // Lógica para añadir entrenamiento
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _buildRoutineCard(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: _buildPredictedRankCard(predictedRank, averageProgress),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Movimiento del cuerpo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(child: BodyMapWidget(bodyAnalysis: analysis)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildPlanSection(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: _buildChallengeCard(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rangos por músculo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...analysis.muscleRanks.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RankCard(
                        muscleGroup: entry.key,
                        rank: entry.value,
                      ),
                    );
                  }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallLevelCard(int level, BodyAnalysis analysis) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryAccent.withOpacity(0.15),
            AppColors.secondaryAccent.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
               gradient: const LinearGradient(
                 colors: [AppColors.primaryAccent, AppColors.secondaryAccent],
                 begin: Alignment.topLeft,
                 end: Alignment.bottomRight,
               ),
               boxShadow: [
                 BoxShadow(
                   color: AppColors.primaryAccent.withOpacity(0.4),
                   blurRadius: 20,
                   spreadRadius: 5,
                 ),
               ],

            ),
            child: Center(
              child: Text(
                '$level',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'OVERALL LEVEL',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                if (analysis.weakPoints.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '⚠️ Work on: ${analysis.weakPoints.take(2).join(', ')}',
                       style: const TextStyle(
                         color: AppColors.fatColor,
                         fontSize: 12,
                         fontWeight: FontWeight.w600,
                       ),

                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (analysis.strongPoints.isNotEmpty)
                  Text(
                    '💪 Strong: ${analysis.strongPoints.take(2).join(', ')}',
                     style: const TextStyle(
                       color: AppColors.proteinColor,
                       fontSize: 12,
                       fontWeight: FontWeight.w600,
                     ),

                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {required VoidCallback onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
                IconButton(
                  onPressed: onTap,
                  icon: const Icon(Icons.add, color: AppColors.proteinColor),
                ),

      ],
    );
  }

  Widget _buildRoutineCard() {
    if (_routines.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.fitness_center, color: AppColors.proteinColor, size: 40),
              const SizedBox(height: 16),
              const Text(
                'Crear tu primera rutina',

              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Añade una rutina y mantén tu plan entrenado.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.proteinColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  disabledBackgroundColor: Colors.grey[700],
                  disabledForegroundColor: Colors.grey,
                ),
                child: const Text('Módulo de entrenamientos desactivado'),
              ),
            ),
          ],
        ),
      );
    }

    final activeRoutine = _routines.first;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Planificación Activa',
              style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12)),
          const SizedBox(height: 6),
          Text(activeRoutine.name,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${activeRoutine.days.length} días · ${activeRoutine.days.fold<int>(0, (sum, day) => sum + day.exercises.length)} ejercicios',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 14),
          Row(
            children: [
              Chip(
                backgroundColor: const Color(0xFF00C853).withOpacity(0.15),
                label: const Text('Activa', style: TextStyle(color: Color(0xFF00C853))),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.calendar_today, color: Colors.white24, size: 16),
              const SizedBox(width: 4),
              const Text('4 días', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPredictedRankCard(StrengthRank currentRank, double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: currentRank.color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.star, color: currentRank.color),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rango predicho', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(currentRank.name,
                      style: TextStyle(color: currentRank.color, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            color: currentRank.color,
            backgroundColor: Colors.white12,
            minHeight: 8,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(progress * 100).toStringAsFixed(0)}% hacia el siguiente rango',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Text(currentRank.name.toUpperCase(),
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 18),
            ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.proteinColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),

              disabledBackgroundColor: Colors.grey[700],
              disabledForegroundColor: Colors.grey,
            ),
            child: const Text('Módulo desactivado', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Planificación',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          const Text('ESTÉTICA MÁXIMA – UPPER LOWER',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
               _buildPlanBadge('Equipo en Casa', AppColors.textSecondary),
               const SizedBox(width: 8),
               _buildPlanBadge('4 días', AppColors.proteinColor),
             ],

          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildDayBadge('L'),
              _buildDayBadge('M'),
              _buildDayBadge('X', isActive: false),
              _buildDayBadge('J'),
              _buildDayBadge('V'),
              _buildDayBadge('S', isActive: false),
              _buildDayBadge('D', isActive: false),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Planificación Activa', style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text('Ver más', style: TextStyle(color: Color(0xFF00C853), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _buildDayBadge(String label, {bool isActive = true}) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isActive ? AppColors.proteinColor : const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(
              color: isActive ? Colors.black : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            )),
      ),
    );
  }

  Widget _buildChallengeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Desafío Inicial',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Completa tu primer entrenamiento',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),
           LinearProgressIndicator(
             value: 0.25,
             color: AppColors.proteinColor,
             backgroundColor: Colors.white12,
             minHeight: 10,
           ),

          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('25%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('Entrenamiento 1/0 · 9h 34m', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BodyAnalysis analysis) {
    final totalWorkouts = analysis.muscleRanks.values
        .fold<int>(0, (sum, rank) => sum + rank.totalWorkouts);
    final avgRank = analysis.muscleRanks.isNotEmpty
        ? analysis.muscleRanks.values
                .fold<double>(0, (sum, rank) => sum + rank.currentRank) /
            analysis.muscleRanks.length
        : 1.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard('TOTAL WORKOUTS', '$totalWorkouts',
                  Icons.fitness_center_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard('AVG RANK', avgRank.toStringAsFixed(1),
                  Icons.trending_up),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                  'GROUPS', '${analysis.muscleRanks.length}', Icons.grid_3x3),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF4ECDC4), size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
