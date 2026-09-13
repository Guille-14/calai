import 'package:flutter/material.dart';
import '../../core/theme/app_constants.dart';

class BodyScanScreen extends StatefulWidget {
  const BodyScanScreen({super.key});

  @override
  State<BodyScanScreen> createState() => _BodyScanScreenState();
}

class _BodyScanScreenState extends State<BodyScanScreen> {
  bool _isScanning = false;
  double _scanProgress = 0.0;

  @override
  void initState() {
    super.initState();
    // Simular inicio de escaneo después de un breve retraso
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isScanning = true;
        });
        _startScanSimulation();
      }
    });
  }

  void _startScanSimulation() {
    const duration = Duration(seconds: 5);
    const interval = Duration(milliseconds: 100);
    final steps = duration.inMilliseconds / interval.inMilliseconds;

    for (int i = 1; i <= steps; i++) {
      Future.delayed(interval * i, () {
        if (mounted) {
          setState(() {
            _scanProgress = i / steps;
          });

          // Finalizar escaneo
          if (i == steps) {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() {
                  _isScanning = false;
                });
              }
            });
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Título y descripción
              Column(
                children: [
                  const Text(
                    'ESCANEO CORPORAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Analiza tu físico con IA para obtener rutinas 100% personalizadas',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // Contenedor de escaneo
              Container(
                width: double.infinity,
                height: 400,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Stack(
                  children: [
                    // Silueta del cuerpo
                    Center(
                      child: Container(
                        width: 200,
                        height: 320,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: CustomPaint(
                          size: const Size(200, 320),
                          painter: _isScanning
                              ? _BodyScanPainter(scanProgress: _scanProgress)
                              : const _BodyScanPainter(scanProgress: 1.0),
                        ),
                      ),
                    ),
                    // Instrucciones
                    if (!_isScanning && _scanProgress < 1.0)
                      const Positioned(
                        top: 20,
                        left: 20,
                        right: 20,
                        child: Text(
                          'Coloca tu cuerpo completo dentro del marco\nMantén la posición estable',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    // Botón de reintento
                    if (!_isScanning && _scanProgress >= 1.0)
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isScanning = true;
                                _scanProgress = 0.0;
                              });
                              _startScanSimulation();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentCalories,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'ESCANEAR DE NUEVO',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Resultados del escaneo (mostrar después del escaneo)
              if (!_isScanning && _scanProgress >= 1.0) ...[
                const Text(
                  'ANÁLISIS COMPLETADO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildScanResultColumn(
                      'GENÉTICA',
                      '85%',
                      'Excelente potencial',
                      AppColors.accentCalories,
                    ),
                    _buildScanResultColumn(
                      'EQUILIBRIO',
                      '72%',
                      'Bueno, mejorar simetría',
                      Colors.orange,
                    ),
                    _buildScanResultColumn(
                      'POTENCIAL',
                      '91%',
                      'Alto desarrollo muscular',
                      Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navegar a rutinas personalizadas
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCalories,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'VER MI RUTINA PERSONALIZADA',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // Información adicional
              if (!_isScanning && _scanProgress >= 1.0)
                Column(
                  children: [
                    Text(
                      'Tu análisis incluye:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Evaluación de composición corporal\n• Análisis de simetría muscular\n• Predicción de potencial genético\n• Recomendaciones de entrenamiento personalizadas',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanResultColumn(
      String label, String value, String description, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _BodyScanPainter extends CustomPainter {
  final double scanProgress;

  const _BodyScanPainter({required this.scanProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentCalories.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Dibujar una silueta corporal simplificada
    final path = Path();

    // Cabeza
    path.addOval(Rect.fromLTWH(
      size.width * 0.45,
      size.height * 0.05,
      size.width * 0.1,
      size.height * 0.1,
    ));

    // Cuello
    path.addRect(Rect.fromLTWH(
      size.width * 0.48,
      size.height * 0.15,
      size.width * 0.04,
      size.height * 0.05,
    ));

    // Hombros
    path.addRect(Rect.fromLTWH(
      size.width * 0.3,
      size.height * 0.2,
      size.width * 0.4,
      size.height * 0.08,
    ));

    // Torso
    path.addRect(Rect.fromLTWH(
      size.width * 0.4,
      size.height * 0.28,
      size.width * 0.2,
      size.height * 0.3,
    ));

    // Cintura
    path.addRect(Rect.fromLTWH(
      size.width * 0.45,
      size.height * 0.58,
      size.width * 0.1,
      size.height * 0.05,
    ));

    // Cadera
    path.addRect(Rect.fromLTWH(
      size.width * 0.35,
      size.height * 0.63,
      size.width * 0.3,
      size.height * 0.08,
    ));

    // Piernas
    path.addRect(Rect.fromLTWH(
      size.width * 0.35,
      size.height * 0.71,
      size.width * 0.12,
      size.height * 0.25,
    ));

    path.addRect(Rect.fromLTWH(
      size.width * 0.53,
      size.height * 0.71,
      size.width * 0.12,
      size.height * 0.25,
    ));

    // Brazos
    path.addRect(Rect.fromLTWH(
      size.width * 0.15,
      size.height * 0.28,
      size.width * 0.1,
      size.height * 0.2,
    ));

    path.addRect(Rect.fromLTWH(
      size.width * 0.75,
      size.height * 0.28,
      size.width * 0.1,
      size.height * 0.2,
    ));

    // Dibujar progreso basado en scanProgress
    final progressHeight = (size.height * 0.7) * scanProgress;
    final progressRect = Rect.fromLTWH(
      size.width * 0.4,
      size.height * 0.28 + (size.height * 0.3 - progressHeight),
      size.width * 0.2,
      progressHeight,
    );

    canvas.drawRect(progressRect, paint..style = PaintingStyle.fill);

    // Dibujar contorno
    canvas.drawPath(path, paint..style = PaintingStyle.stroke);

    // Efecto de escaneo activo
    if (scanProgress < 1.0) {
      final glowPaint = Paint()
        ..color = AppColors.accentCalories.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6;

      canvas.drawRect(progressRect, glowPaint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant _BodyScanPainter oldDelegate) =>
      oldDelegate.scanProgress != scanProgress;
}
