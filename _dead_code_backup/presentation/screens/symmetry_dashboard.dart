import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/symmetry/symmetry_progression_service.dart';
import '../../core/symmetry/muscle_fatigue_map.dart';
import '../../core/symmetry/macro_bridge.dart';
import '../../core/symmetry/symmetry_rank_system.dart';
import '../widgets/rank_badge_widget.dart';
import '../widgets/nutrition_boost_widget.dart';
import '../widgets/symmetry_heatmap_widget.dart';
import 'symmetry_recommendations_screen.dart';
import '../widgets/hevy_sync_button_widget.dart';

class SymmetryDashboard extends StatefulWidget {
  const SymmetryDashboard({Key? key}) : super(key: key);

  @override
  State<SymmetryDashboard> createState() => _SymmetryDashboardState();
}

class _SymmetryDashboardState extends State<SymmetryDashboard> {
  late SymmetryProgressionService _progressionService;
  late MacroBridge _macroBridge;
  late MuscleFatigueMap _fatigueMap;

  @override
  void initState() {
    super.initState();
    _progressionService = SymmetryProgressionService();
    _macroBridge = MacroBridge();
    _fatigueMap = MuscleFatigueMap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // SliverAppBar con fondo RPG
          SliverAppBar(
            expandedHeight: 120,
            backgroundColor: AppColors.rpgDark,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.rpgDark,
                      AppColors.rpgCardDark,
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.neonGreen.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Título central
                    Text(
                      'SYMMETRY ENGINE',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.neonGreen,
                        letterSpacing: 3,
                        shadows: [
                          Shadow(
                            color: AppColors.neonGreen.withOpacity(0.6),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    // Botón de sincronización en esquina superior derecha
                    Positioned(
                      right: 16,
                      bottom: 12,
                      child: HevySyncButtonWidget(
                        showLabel: true,
                        onSyncComplete: () {
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ),
              centerTitle: true,
            ),
            pinned: true,
            floating: true,
            elevation: 0,
          ),

          // Contenido principal
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rango del jugador
                  FutureBuilder<SymmetryProgress>(
                    future: _progressionService.getCurrentProgress(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return _buildLoadingShimmer();
                      }

                      final progress = snapshot.data!;
                      return RankBadgeWidget(
                        progress: progress,
                        onTap: () => _showRankDetails(context, progress),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Buff de Recuperación (CalAI)
                  FutureBuilder<Map<String, dynamic>>(
                    future: _macroBridge.getDailyMacroStatus(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }

                      final macroStatus = snapshot.data!;
                      final isProteinGoalMet = macroStatus['isGoalMet'] ?? false;
                      final proteinPercent =
                          (macroStatus['percentage'] as num?)?.toDouble() ?? 0;

                      return NutritionBoostWidget(
                        isActive: isProteinGoalMet,
                        multiplier: isProteinGoalMet ? 1.2 : 1.0,
                        proteinPercent: proteinPercent,
                        proteinStatus: isProteinGoalMet
                            ? '✓ Objetivo de proteína alcanzado'
                            : 'Faltan ${(macroStatus['remaining'] ?? 0)}g de proteína',
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Sección Mapa de Fatiga Muscular
                  _buildSectionTitle('ANÁLISIS DE MÚSCULOS'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.rpgCardDark,
                      border: Border.all(
                        color: AppColors.neonCyan.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: SymmetryHeatmapWidget(
                      muscleFatigueMap: _fatigueMap,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Estadísticas rápidas
                  _buildSectionTitle('ESTADÍSTICAS'),
                  const SizedBox(height: 12),
                  FutureBuilder<Map<String, dynamic>>(
                    future: _buildStatsMap(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator(
                          color: AppColors.neonGreen,
                        );
                      }

                      final stats = snapshot.data!;
                      return _buildStatGrid(stats);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Recomendaciones
                  _buildSectionTitle('RECOMENDACIONES'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.rpgCardDark,
                      border: Border.all(
                        color: AppColors.neonPurple.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: SymmetryRecommendationsScreen(
                      muscleFatigueMap: _fatigueMap,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _buildStatsMap() async {
    final progress = await _progressionService.getCurrentProgress();
    final fatigueAnalysis = _fatigueMap.analyzeSymmetry();

    return {
      'totalXP': progress.totalXP,
      'todayXP': await _progressionService.getTodayXPGained(),
      'streak': progress.currentStreak,
      'symmetryScore':
          (fatigueAnalysis['symmetryScore'] as num?)?.toDouble() ?? 0,
      'averageFatigue': (fatigueAnalysis['averageFatigue'] as num?)?.toDouble() ?? 0,
    };
  }

  Widget _buildStatGrid(Map<String, dynamic> stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildStatCard(
          title: 'XP Hoy',
          value: '${(stats['todayXP'] as num?)?.toStringAsFixed(0) ?? '0'} XP',
          icon: Icons.flash_on,
          color: AppColors.neonGreen,
        ),
        _buildStatCard(
          title: 'Racha',
          value: '${stats['streak'] ?? 0} días',
          icon: Icons.local_fire_department,
          color: AppColors.neonOrange,
        ),
        _buildStatCard(
          title: 'Simetría',
          value:
              '${((stats['symmetryScore'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%',
          icon: Icons.balance,
          color: AppColors.neonCyan,
        ),
        _buildStatCard(
          title: 'Fatiga Media',
          value:
              '${((stats['averageFatigue'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}%',
          icon: Icons.sentiment_very_satisfied,
          color: AppColors.neonMagenta,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.rpgCardDark,
            AppColors.rpgCardDark.withOpacity(0.6),
          ],
        ),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.neonGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.neonGreen,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingShimmer() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.rpgCardDark,
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.neonGreen,
        ),
      ),
    );
  }

  void _showRankDetails(BuildContext context, SymmetryProgress progress) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.rpgCardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: AppColors.neonGreen,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                progress.currentRank.displayName.toUpperCase(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: progress.currentRank.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'XP: ${progress.totalXP.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Racha: ${progress.currentStreak} días',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(color: AppColors.rpgDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
