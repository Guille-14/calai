import '../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/symmetry/symmetry_rank_system.dart';
import '../../core/symmetry/symmetry_progression_service.dart';

class SymmetryRanksScreen extends StatefulWidget {
  const SymmetryRanksScreen({super.key});

  @override
  State<SymmetryRanksScreen> createState() => _SymmetryRanksScreenState();
}

class _SymmetryRanksScreenState extends State<SymmetryRanksScreen> {
  static const Color _accent = AppColors.accent;
  static const Color _bg = AppColors.background;
  static const Color _card = AppColors.cardBackground;

  final SymmetryProgressionService _service = SymmetryProgressionService();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _service.initialize();
    } catch (_) {
      // El progreso por defecto (vacío) es válido si falla la carga
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  String _formatXP(double xp) {
    if (xp >= 1000000) {
      return '${(xp / 1000000).toStringAsFixed(1)}M';
    }
    if (xp >= 1000) {
      return '${(xp / 1000).toStringAsFixed(1)}k';
    }
    return xp.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        color: _bg,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _accent),
              )
            : RefreshIndicator(
                color: _accent,
                backgroundColor: _card,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: _buildContent(),
                ),
              ),
      ),
    );
  }

  List<Widget> _buildContent() {
    final progress = _service.getProgress();
    final current = progress.currentRank;
    final next = current.nextRank;

    return [
      _buildHero(progress, current, next),
      const SizedBox(height: 24),
      Text(
        'JERARQUÍA DE RANGOS',
        style: TextStyle(
          color: AppColors.textPrimary.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
      const SizedBox(height: 12),
      ...SymmetryRank.values.map((rank) {
        final achieved = progress.totalXP >= rank.minXP;
        final isCurrent = rank == current;
        return _buildRankRow(rank, achieved, isCurrent, progress.totalXP);
      }),
      const SizedBox(height: 24),
      _buildStatsCard(progress),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildHero(
      SymmetryProgress progress, SymmetryRank current, SymmetryRank? next) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: current.color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: current.color.withValues(alpha: 0.15),
              border: Border.all(color: current.color, width: 2.5),
            ),
            child: Center(
              child: Text(
                '${current.level}',
                style: TextStyle(
                  color: current.color,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            current.displayName.toUpperCase(),
            style: TextStyle(
              color: current.color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatXP(progress.totalXP)} XP totales',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.rankProgress,
              minHeight: 10,
              backgroundColor: AppColors.textPrimary.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(current.color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            next == null
                ? 'Rango máximo alcanzado'
                : '${_formatXP((progress.totalXP - current.minXP).clamp(0, double.infinity))} / ${_formatXP(next.minXP - current.minXP)} XP para ${next.displayName}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRankRow(
      SymmetryRank rank, bool achieved, bool isCurrent, double totalXP) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrent ? rank.color.withValues(alpha: 0.12) : _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? rank.color : AppColors.textPrimary.withValues(alpha: 0.06),
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: achieved
                  ? rank.color.withValues(alpha: 0.2)
                  : AppColors.textPrimary.withValues(alpha: 0.05),
            ),
            child: Icon(
              achieved ? rank.icon : Icons.lock_outline,
              size: 20,
              color: achieved ? rank.color : AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rank.displayName,
                      style: TextStyle(
                        color: achieved ? AppColors.textPrimary : AppColors.textTertiary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'ACTUAL',
                          style: TextStyle(
                            color: _accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Nivel ${rank.level} · desde ${_formatXP(rank.minXP)} XP',
                  style: TextStyle(
                    color:
                        achieved ? AppColors.textSecondary : AppColors.textPrimary.withValues(alpha: 0.25),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(SymmetryProgress progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat('Hoy', '${progress.dailyXP.round()}', Icons.today_outlined),
          _buildStat('Semana', '${progress.weeklyXP.round()}', Icons.date_range_outlined),
          _buildStat('Racha', '${progress.streakDays.round()} d', Icons.local_fire_department_outlined),
          _buildStat(
            'Proteína',
            progress.metProteinGoal ? 'x${progress.proteinMultiplier.toStringAsFixed(1)}' : 'x1.0',
            Icons.restaurant_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: _accent, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.4), fontSize: 11),
        ),
      ],
    );
  }
}
