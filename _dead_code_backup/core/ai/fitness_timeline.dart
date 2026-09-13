import 'package:flutter/material.dart';
import 'fitness_memory_profile.dart';
import 'ai_orchestrator.dart';

class FitnessTimelineData {
  final DateTime date;
  final bool isTrainingDay;
  final bool isRestDay;
  final int caloriesBurned;
  final int caloriesConsumed;
  final double recoveryScore;
  final int hydrationLevel;
  final double nutritionBalance;
  final double fatigueLevel;
  final String? workoutName;
  final int workoutDuration;
  final double volume;

  FitnessTimelineData({
    required this.date,
    required this.isTrainingDay,
    required this.isRestDay,
    required this.caloriesBurned,
    required this.caloriesConsumed,
    required this.recoveryScore,
    required this.hydrationLevel,
    required this.nutritionBalance,
    required this.fatigueLevel,
    this.workoutName,
    this.workoutDuration = 0,
    this.volume = 0,
  });
}

class FitnessTimelineService {
  final AiOrchestrator _ai = AiOrchestrator();

  List<FitnessTimelineData> buildTimeline(List<DailyFitnessRecord> records,
      {int days = 30}) {
    final timeline = <FitnessTimelineData>[];
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final record = records
          .where((r) =>
              r.date.year == date.year &&
              r.date.month == date.month &&
              r.date.day == date.day)
          .firstOrNull;

      if (record != null) {
        timeline.add(FitnessTimelineData(
          date: record.date,
          isTrainingDay: record.workoutDurationMinutes > 0,
          isRestDay: record.isRestDay || record.workoutDurationMinutes == 0,
          caloriesBurned: record.caloriesBurned,
          caloriesConsumed: record.caloriesConsumed,
          recoveryScore: _calculateDayRecovery(records, record),
          hydrationLevel: record.waterGlasses,
          nutritionBalance: record.getCalorieBalance,
          fatigueLevel: record.trainingLoad ?? 0,
          workoutName: record.muscleGroupsWorked.isNotEmpty
              ? record.muscleGroupsWorked.first
              : null,
          workoutDuration: record.workoutDurationMinutes,
          volume: record.totalVolumeKg,
        ));
      } else {
        timeline.add(FitnessTimelineData(
          date: date,
          isTrainingDay: false,
          isRestDay: true,
          caloriesBurned: 0,
          caloriesConsumed: 0,
          recoveryScore: 50,
          hydrationLevel: 0,
          nutritionBalance: 0,
          fatigueLevel: 0,
        ));
      }
    }

    return timeline.reversed.toList();
  }

  double _calculateDayRecovery(
      List<DailyFitnessRecord> records, DailyFitnessRecord today) {
    final dayIndex = records.indexOf(today);
    if (dayIndex < 0 || dayIndex >= records.length - 1) {
      return 50;
    }

    final nextDay = records[dayIndex + 1];
    final hasRest = nextDay.isRestDay || nextDay.workoutDurationMinutes == 0;

    if (hasRest && (today.trainingLoad ?? 0) < 80) {
      return 80;
    } else if ((today.trainingLoad ?? 0) > 80) {
      return 30;
    }
    return 60;
  }

  String generateNarrative(List<FitnessTimelineData> timeline) {
    final trainingDays = timeline.where((d) => d.isTrainingDay).length;
    final restDays = timeline.where((d) => d.isRestDay).length;
    final avgCalories =
        timeline.fold<int>(0, (s, d) => s + d.caloriesConsumed) /
            timeline.length;
    final avgHydration =
        timeline.fold<int>(0, (s, d) => s + d.hydrationLevel) / timeline.length;

    final StringBuffer narrative = StringBuffer();
    narrative.writeln('RESUMEN DEL ÚLTIMO MES');
    narrative.writeln('');
    narrative.writeln('📅 Días de entrenamiento: $trainingDays');
    narrative.writeln('😴 Días de descanso: $restDays');
    narrative.writeln('');
    narrative.writeln('🔥 Promedio calórico: ${avgCalories.toInt()} kcal/día');
    narrative.writeln('💧 Hidratación: ${avgHydration.toInt()} vasos/día');

    final highFatigue = timeline.where((d) => d.fatigueLevel > 80).length;
    if (highFatigue > 3) {
      narrative.writeln('');
      narrative.writeln(
          '⚠️ Se detectaron $highFatigue días con alta carga de entrenamiento.');
      narrative.writeln('Considera incluir más días de recuperación.');
    }

    return narrative.toString();
  }

  Future<String> generateAiNarrative(List<FitnessTimelineData> timeline) async {
    final basicNarrative = generateNarrative(timeline);
    final prompt =
        'Convierte el siguiente resumen de datos fitness en una narrativa motivacional, profesional y analítica para un atleta. '
        'Resalta los logros, identifica patrones de fatiga y sugiere ajustes basados en la consistencia. '
        'Usa un tono de coach experto. Resumen: $basicNarrative';

    final result = await _ai.executeTextTask(prompt,
        systemMessage:
            'Eres un experto coach de rendimiento deportivo y analista de datos fisiológicos.');

    if (result.isError) return basicNarrative;
    return result.data?['response'] ?? basicNarrative;
  }

  List<String> getWeeklyPlan(List<FitnessTimelineData> timeline) {
    final recent = timeline.take(7).toList();
    final trainingDays = recent.where((d) => d.isTrainingDay).length;
    final avgFatigue =
        recent.fold<double>(0, (s, d) => s + d.fatigueLevel) / recent.length;

    final plan = <String>[];

    if (trainingDays < 3 || avgFatigue < 40) {
      plan.add('Lun: Entrenamiento - Pierna');
      plan.add('Mar: Entrenamiento - Pecho');
      plan.add('Mié: Descanso');
      plan.add('Jue: Entrenamiento - Espalda');
      plan.add('Vie: Entrenamiento - Hombros');
      plan.add('Sáb: Entrenamiento - Brazos');
      plan.add('Dom: Descanso');
    } else if (trainingDays >= 5 || avgFatigue > 70) {
      plan.add('Lun: Descanso activo');
      plan.add('Mar: Entrenamiento ligero');
      plan.add('Mié: Descanso');
      plan.add('Jue: Entrenamiento moderado');
      plan.add('Vie: Descanso');
      plan.add('Sáb: Entrenamiento ligero');
      plan.add('Dom: Descanso completo');
    } else {
      plan.add('Lun: Entrenamiento');
      plan.add('Mar: Entrenamiento');
      plan.add('Mié: Descanso');
      plan.add('Jue: Entrenamiento');
      plan.add('Vie: Entrenamiento');
      plan.add('Sáb: Descanso');
      plan.add('Dom: Descanso');
    }

    return plan;
  }
}

class TimelineCalendarWidget extends StatelessWidget {
  final List<FitnessTimelineData> timeline;
  final Function(DateTime)? onDayTap;

  const TimelineCalendarWidget({
    super.key,
    required this.timeline,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: timeline.length,
      itemBuilder: (context, index) {
        final day = timeline[index];
        return _DayCell(
          data: day,
          onTap: onDayTap != null ? () => onDayTap!(day.date) : null,
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  final FitnessTimelineData data;
  final VoidCallback? onTap;

  const _DayCell({required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    IconData? icon;

    if (data.isTrainingDay) {
      backgroundColor = Colors.green.shade800;
      icon = Icons.fitness_center;
    } else if (data.isRestDay) {
      backgroundColor = Colors.grey.shade800;
      icon = Icons.bedtime;
    } else {
      backgroundColor = Colors.transparent;
    }

    if (data.fatigueLevel > 80 && data.isTrainingDay) {
      backgroundColor = Colors.red.shade800;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) Icon(icon, size: 12, color: Colors.white70),
            Text(
              '${data.date.day}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TimelineSummaryWidget extends StatelessWidget {
  final FitnessTimelineData today;
  final FitnessTimelineData? yesterday;

  const TimelineSummaryWidget({
    super.key,
    required this.today,
    this.yesterday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hoy: ${today.date.day}/${today.date.month}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildStatusChip(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetric('🔥', '${today.caloriesConsumed}', 'kcal'),
              const SizedBox(width: 16),
              _buildMetric('💧', '${today.hydrationLevel}', 'vasos'),
              const SizedBox(width: 16),
              _buildMetric('⚡', '${today.recoveryScore.toInt()}', '%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    String label;
    Color color;

    if (today.isTrainingDay) {
      label = 'Entrenamiento';
      color = Colors.green;
    } else if (today.isRestDay) {
      label = 'Descanso';
      color = Colors.grey;
    } else {
      label = 'Normal';
      color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  Widget _buildMetric(String emoji, String value, String unit) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(
          '$value $unit',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
