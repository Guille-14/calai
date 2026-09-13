import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Widget que visualiza el mapa de calor muscular con forma de cuerpo humano
/// Cada grupo muscular tiene un nivel de fatiga de 0.0 (verde/recuperado) a 1.0 (rojo/agotado)
class BodyMuscleHeatmapWidget extends StatefulWidget {
  /// Mapa de grupos musculares con sus valores de fatiga (0.0-1.0)
  final Map<String, double> musclesFatigue;

  /// Callback cuando se selecciona un músculo
  final Function(String muscleName, double fatigueValue)? onMuscleTapped;

  const BodyMuscleHeatmapWidget({
    Key? key,
    required this.musclesFatigue,
    this.onMuscleTapped,
  }) : super(key: key);

  @override
  State<BodyMuscleHeatmapWidget> createState() =>
      _BodyMuscleHeatmapWidgetState();
}

class _BodyMuscleHeatmapWidgetState extends State<BodyMuscleHeatmapWidget> {
  String? _selectedMuscle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.rpgCardDark,
        border: Border.all(
          color: AppColors.neonGreen.withOpacity(0.3),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Row(
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
              const Text(
                'ESTADO MUSCULAR',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neonGreen,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Cuerpo visual
          _buildBodyVisualization(),
          const SizedBox(height: 20),

          // Leyenda de colores
          _buildColorLegend(),
          const SizedBox(height: 16),

          // Información del músculo seleccionado
          if (_selectedMuscle != null)
            _buildSelectedMuscleInfo()
          else
            _buildAverageFatigue(),
        ],
      ),
    );
  }

  Widget _buildBodyVisualization() {
    return Center(
      child: SizedBox(
        width: 150,
        height: 350,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Silueta del cuerpo con grupos musculares
            ..._buildMuscleRegions(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMuscleRegions() {
    final regions = [
      // Cabeza (referencia, no muscular)
      _MuscleRegion(
        name: 'head',
        top: 0,
        left: 50,
        width: 50,
        height: 30,
        shape: 'circle',
        fatigue: 0.0,
      ),

      // Hombros
      _MuscleRegion(
        name: 'Hombros',
        top: 35,
        left: 15,
        width: 35,
        height: 20,
        shape: 'rect',
        fatigue: widget.musclesFatigue['Hombros'] ?? 0.0,
      ),

      // Pecho
      _MuscleRegion(
        name: 'Pecho',
        top: 60,
        left: 40,
        width: 60,
        height: 40,
        shape: 'rect',
        fatigue: widget.musclesFatigue['Pecho'] ?? 0.0,
      ),

      // Espalda (similar a pecho, zona media)
      _MuscleRegion(
        name: 'Espalda',
        top: 70,
        left: 5,
        width: 30,
        height: 35,
        shape: 'rect',
        fatigue: widget.musclesFatigue['Espalda'] ?? 0.0,
      ),

      // Bíceps izquierdo
      _MuscleRegion(
        name: 'Bíceps Izq',
        top: 50,
        left: 5,
        width: 12,
        height: 45,
        shape: 'rect',
        fatigue: widget.musclesFatigue['Bíceps Izq'] ?? 0.0,
      ),

      // Bíceps derecho
      _MuscleRegion(
        name: 'Bíceps Der',
        top: 50,
        left: 133,
        width: 12,
        height: 45,
        shape: 'rect',
        fatigue: widget.musclesFatigue['Bíceps Der'] ?? 0.0,
      ),

      // Abdominales
      _MuscleRegion(
        name: 'Abdominales',
        top: 100,
        left: 50,
        width: 40,
        height: 35,
        shape: 'rect',
        fatigue: widget.musclesFatigue['Abdominales'] ?? 0.0,
      ),

      // Espalda baja
      _MuscleRegion(
        name: 'Espalda Baja',
        top: 110,
        left: 10,
        width: 25,
        height: 30,
        shape: 'rect',
        fatigue: widget.musclesFatigue['Espalda Baja'] ?? 0.0,
      ),

      // Cuádriceps izquierdo
      _MuscleRegion(
        name: 'Cuádriceps Izq',
        top: 155,
        left: 30,
        width: 20,
        height: 65,
        shape: 'rect',
        fatigue: widget.musclesFatigue['Cuádriceps Izq'] ?? 0.0,
      ),

      // Cuádriceps derecho
      _MuscleRegion(
        name: 'Cuádriceps Der',
        top: 155,
        left: 100,
        width: 20,
        height: 65,
        shape: 'rect',
        fatigue: widget.musclesFatigue['Cuádriceps Der'] ?? 0.0,
      ),

      // Pantorrilla izquierda
      _MuscleRegion(
        name: 'Pantorrilla Izq',
        top: 220,
        left: 30,
        width: 18,
        height: 45,
        shape: 'rect',
        fatigue: widget.musclesFatigue['Pantorrilla Izq'] ?? 0.0,
      ),

      // Pantorrilla derecha
      _MuscleRegion(
        name: 'Pantorrilla Der',
        top: 220,
        left: 102,
        width: 18,
        height: 45,
        shape: 'rect',
        fatigue: widget.musclesFatigue['Pantorrilla Der'] ?? 0.0,
      ),

      // Glúteos (parte trasera, difícil de visualizar)
      _MuscleRegion(
        name: 'Glúteos',
        top: 140,
        left: 55,
        width: 40,
        height: 25,
        shape: 'rect',
        fatigue: widget.musclesFatigue['Glúteos'] ?? 0.0,
      ),
    ];

    return regions.map((region) {
      final color = _getFatigueColor(region.fatigue);
      final isSelected = _selectedMuscle == region.name;

      return Positioned(
        top: region.top,
        left: region.left,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedMuscle = region.name;
            });
            widget.onMuscleTapped?.call(region.name, region.fatigue);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: region.width,
            height: region.height,
            decoration: BoxDecoration(
              color: color.withOpacity(0.7),
              border: Border.all(
                color: isSelected ? AppColors.neonGreen : color,
                width: isSelected ? 2 : 1.5,
              ),
              borderRadius: region.shape == 'circle'
                  ? BorderRadius.circular(region.width / 2)
                  : BorderRadius.circular(4),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.6),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: region.name != 'head'
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      // Tooltip con fatiga
                      Tooltip(
                        message:
                            '${region.name}: ${(region.fatigue * 100).toStringAsFixed(0)}% fatiga',
                        child: Container(),
                      ),
                      // Indicador de fatiga en el centro
                      if (isSelected)
                        Text(
                          '${(region.fatigue * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  )
                : null,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildColorLegend() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.rpgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.neonCyan.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem('Recuperado', _getFatigueColor(0.0)),
          _buildLegendItem('Normal', _getFatigueColor(0.33)),
          _buildLegendItem('Fatigado', _getFatigueColor(0.66)),
          _buildLegendItem('Agotado', _getFatigueColor(1.0)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedMuscleInfo() {
    final fatigue = widget.musclesFatigue[_selectedMuscle] ?? 0.0;
    final fatiguePercent = (fatigue * 100).toStringAsFixed(0);
    final fatigueLabel = _getFatigueLabel(fatigue);
    final fatigueColor = _getFatigueColor(fatigue);

    return Container(
      decoration: BoxDecoration(
        color: fatigueColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: fatigueColor.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: fatigueColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedMuscle!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$fatiguePercent% - $fatigueLabel',
                  style: TextStyle(
                    fontSize: 11,
                    color: fatigueColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Progress circular
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: fatigue,
                  backgroundColor: AppColors.rpgDark,
                  valueColor: AlwaysStoppedAnimation<Color>(fatigueColor),
                  strokeWidth: 3,
                ),
                Text(
                  '$fatiguePercent%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: fatigueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAverageFatigue() {
    if (widget.musclesFatigue.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.rpgDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.neonCyan.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: const Center(
          child: Text(
            'Selecciona un músculo para ver detalles',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final avgFatigue = widget.musclesFatigue.values.reduce((a, b) => a + b) /
        widget.musclesFatigue.length;
    final avgPercent = (avgFatigue * 100).toStringAsFixed(0);
    final avgLabel = _getFatigueLabel(avgFatigue);
    final avgColor = _getFatigueColor(avgFatigue);

    return Container(
      decoration: BoxDecoration(
        color: avgColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: avgColor.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: avgColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fatiga Promedio',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$avgPercent% - $avgLabel',
                  style: TextStyle(
                    fontSize: 11,
                    color: avgColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Progress circular
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: avgFatigue,
                  backgroundColor: AppColors.rpgDark,
                  valueColor: AlwaysStoppedAnimation<Color>(avgColor),
                  strokeWidth: 3,
                ),
                Text(
                  '$avgPercent%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: avgColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Obtiene el color basado en el nivel de fatiga (0.0-1.0)
  Color _getFatigueColor(double fatigue) {
    // Verde (0.0) → Amarillo → Naranja → Rojo (1.0)
    if (fatigue < 0.33) {
      // Verde a Amarillo
      final t = fatigue / 0.33;
      return Color.lerp(
        AppColors.neonGreen,
        const Color(0xFFFFDD00),
        t,
      )!;
    } else if (fatigue < 0.66) {
      // Amarillo a Naranja
      final t = (fatigue - 0.33) / 0.33;
      return Color.lerp(
        const Color(0xFFFFDD00),
        AppColors.neonOrange,
        t,
      )!;
    } else {
      // Naranja a Rojo
      final t = (fatigue - 0.66) / 0.34;
      return Color.lerp(
        AppColors.neonOrange,
        AppColors.neonRed,
        t,
      )!;
    }
  }

  /// Obtiene una etiqueta descriptiva del nivel de fatiga
  String _getFatigueLabel(double fatigue) {
    if (fatigue < 0.25) return 'Recuperado';
    if (fatigue < 0.50) return 'Normal';
    if (fatigue < 0.75) return 'Fatigado';
    return 'Agotado';
  }
}

/// Clase auxiliar para representar regiones musculares
class _MuscleRegion {
  final String name;
  final double top;
  final double left;
  final double width;
  final double height;
  final String shape; // 'rect' o 'circle'
  final double fatigue;

  _MuscleRegion({
    required this.name,
    required this.top,
    required this.left,
    required this.width,
    required this.height,
    required this.shape,
    required this.fatigue,
  });
}
