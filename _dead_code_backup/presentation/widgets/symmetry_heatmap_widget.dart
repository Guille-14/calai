import 'package:flutter/material.dart';

/// Widget que visualiza el mapa muscular en blanco y negro (estética industrial)
class SymmetryHeatmapWidget extends StatelessWidget {
  final Map<String, double> heatMapData;

  const SymmetryHeatmapWidget({
    Key? key,
    required this.heatMapData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MAPA MUSCULAR',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          // Gráfica de barras simplificada en B&W
          ...heatMapData.entries
              .map((entry) => _buildMuscleBar(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildMuscleBar(String name, double fatigue) {
    // Escala de grises: 0% fatiga = 100% blanco (barra vacía), 100% fatiga = 100% blanco (barra llena)
    // O mejor: 0% = línea fina blanca, 100% = barra sólida blanca
    final widthFactor = (fatigue / 100).clamp(0.05, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              name.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white, fontSize: 10, letterSpacing: 1),
            ),
          ),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                widthFactor: widthFactor,
                alignment: Alignment.centerLeft,
                child: Container(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
