import 'package:flutter/material.dart';
import '../../core/symmetry/symmetry_progression_service.dart';
import '../../core/symmetry/symmetry_rank_system.dart';
import '../widgets/symmetry_heatmap_widget.dart';

/// Pantalla de recomendaciones y estado del Symmetry Engine
class SymmetryRecommendationsScreen extends StatefulWidget {
  const SymmetryRecommendationsScreen({Key? key}) : super(key: key);

  @override
  State<SymmetryRecommendationsScreen> createState() =>
      _SymmetryRecommendationsScreenState();
}

class _SymmetryRecommendationsScreenState
    extends State<SymmetryRecommendationsScreen> {
  late final SymmetryProgressionService _progressionService;
  SymmetryProgress? _progress;
  Map<String, dynamic>? _fullStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _progressionService = SymmetryProgressionService();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    try {
      await _progressionService.initialize();
      final progress = _progressionService.getProgress();
      final stats = _progressionService.getFullStats();

      setState(() {
        _progress = progress;
        _fullStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading recommendations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _initializeAndLoad();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _progress == null || _fullStats == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.purpleAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          slivers: [
            // AppBar customizado
            SliverAppBar(
              expandedHeight: 200,
              floating: true,
              pinned: true,
              backgroundColor: Colors.black,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'Symmetry Engine',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.purpleAccent.withOpacity(0.2),
                        Colors.blueAccent.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildRankDisplay(),
                  ),
                ),
              ),
            ),

            // Contenido principal
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sección de progreso
                    _buildProgressSection(),
                    const SizedBox(height: 20),

                    // Heatmap
                    _buildHeatmapSection(),
                    const SizedBox(height: 20),

                    // Recomendaciones de entrenamiento
                    _buildRecommendationsSection(),
                    const SizedBox(height: 20),

                    // Estadísticas de proteína
                    _buildProteinSection(),
                    const SizedBox(height: 20),

                    // Estadísticas de entrenamiento
                    _buildTrainingStatsSection(),
                    const SizedBox(height: 20),

                    // Secciones de músculos
                    _buildMuscleAnalysisSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye la visualización del rango
  Widget _buildRankDisplay() {
    final rankColor = _progress!.currentRank.color;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [rankColor.withOpacity(0.4), rankColor.withOpacity(0.8)],
            ),
            border: Border.all(color: rankColor, width: 3),
          ),
          child: Center(
            child: Text(
              _progress!.currentRank.displayName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: rankColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Rango actual',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  /// Construye la sección de progreso
  Widget _buildProgressSection() {
    final nextRank = _progress!.currentRank.nextRank;
    final xpRemaining = nextRank != null
        ? (nextRank.minXP - _progress!.totalXP).clamp(0, double.infinity)
        : 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progreso de Rango',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress!.rankProgress,
              minHeight: 8,
              backgroundColor: Colors.grey[700],
              valueColor: AlwaysStoppedAnimation<Color>(
                _progress!.currentRank.color,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'XP: ${_progress!.totalXP.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              if (nextRank != null)
                Text(
                  'Falta: ${xpRemaining.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.purpleAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Diarios: ${_progress!.dailyXP.toStringAsFixed(0)} XP | Semanales: ${_progress!.weeklyXP.toStringAsFixed(0)} XP',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye la sección del heatmap
  Widget _buildHeatmapSection() {
    final heatMap = _fullStats!['fatigueMap']['heatMap']
        as Map<String, double>? ??
        {};
    final symmetryScore =
        _fullStats!['fatigueMap']['symmetryScore'] as double? ?? 0;

    if (heatMap.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: const Text(
          'No hay datos de entrenamiento aún',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SymmetryHeatmapWidget(
      heatMapData: heatMap,
      symmetryScore: symmetryScore,
      onRefresh: _refreshData,
    );
  }

  /// Construye la sección de recomendaciones
  Widget _buildRecommendationsSection() {
    final recommendations = _progressionService.getWorkoutRecommendations();

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recomendaciones de Hoy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...recommendations.map((rec) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: Colors.greenAccent, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    rec,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  /// Construye la sección de proteína
  Widget _buildProteinSection() {
    final macroBridge = _fullStats!['macroBridge'] as Map<String, dynamic>;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (macroBridge['metGoal'] as bool)
              ? Colors.greenAccent.withOpacity(0.5)
              : Colors.orangeAccent.withOpacity(0.5),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Proteína del Día',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (macroBridge['metGoal'] as bool)
                      ? Colors.green.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'x${(macroBridge['multiplier'] as double).toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: (macroBridge['metGoal'] as bool)
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: ((macroBridge['dailyProtein'] as double) /
                    (macroBridge['proteinGoal'] as double))
                .clamp(0, 1),
            minHeight: 8,
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation<Color>(
              (macroBridge['metGoal'] as bool) ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(macroBridge['dailyProtein'] as double).toStringAsFixed(0)}g / ${(macroBridge['proteinGoal'] as double).toStringAsFixed(0)}g',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            macroBridge['statusMessage'] as String,
            style: TextStyle(
              fontSize: 11,
              color: (macroBridge['metGoal'] as bool)
                  ? Colors.green
                  : Colors.orange,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye la sección de estadísticas de entrenamiento
  Widget _buildTrainingStatsSection() {
    final healthBridge = _fullStats!['healthBridge'] as Map<String, dynamic>;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estadísticas de Entrenamiento',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatItem(
            'Total de sesiones',
            '${healthBridge['totalWorkouts']}',
            Icons.fitness_center,
          ),
          _buildStatItem(
            'Tonelaje total',
            '${(healthBridge['totalTonnage'] as double).toStringAsFixed(0)} kg',
            Icons.monitor_weight,
          ),
          _buildStatItem(
            'Duración total',
            '${healthBridge['totalDurationMinutes']} min',
            Icons.timer,
          ),
          _buildStatItem(
            'Racha de días',
            '${_progress!.streakDays.toInt()} días',
            Icons.local_fire_department,
          ),
        ],
      ),
    );
  }

  /// Construye un item de estadística
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.purpleAccent, size: 18),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye la sección de análisis muscular
  Widget _buildMuscleAnalysisSection() {
    final fatigueData = _fullStats!['fatigueMap'] as Map<String, dynamic>;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Análisis Muscular',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _buildMuscleGroup(
            'Músculos Más Fatigados',
            fatigueData['fatiguedMuscles'] as List<dynamic>,
            Colors.red,
          ),
          const SizedBox(height: 12),
          _buildMuscleGroup(
            'Músculos Recuperados',
            fatigueData['recoveredMuscles'] as List<dynamic>,
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildMuscleGroup(
            'Desequilibrados',
            fatigueData['imbalancedMuscles'] as List<dynamic>,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  /// Construye un grupo muscular
  Widget _buildMuscleGroup(
    String title,
    List<dynamic> muscles,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        if (muscles.isEmpty)
          Text(
            'Ninguno',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          )
        else
          Wrap(
            spacing: 8,
            children: muscles
                .map((muscle) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    border: Border.all(color: color.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    muscle.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                    ),
                  ),
                ))
                .toList(),
          ),
      ],
    );
  }
}
