import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/symmetry/health_connect_importer.dart';
import '../../core/symmetry/health_connect_bridge.dart';
import '../../core/symmetry/symmetry_progression_service.dart';

class HevySyncScreen extends StatefulWidget {
  const HevySyncScreen({Key? key}) : super(key: key);

  @override
  State<HevySyncScreen> createState() => _HevySyncScreenState();
}

class _HevySyncScreenState extends State<HevySyncScreen> {
  late HealthConnectImporter _healthImporter;
  late HealthConnectBridge _healthBridge;
  late SymmetryProgressionService _progressionService;

  bool _isLoading = false;
  String? _statusMessage;
  int? _workoutsImported;
  int? _totalWorkouts;
  DateTime? _lastSync;
  bool _hasPermissions = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _healthBridge = HealthConnectBridge();
    _healthImporter = HealthConnectImporter();
    _progressionService = SymmetryProgressionService();
    _checkPermissionsAndSync();
  }

  Future<void> _checkPermissionsAndSync() async {
    setState(() => _isLoading = true);

    try {
      // Verificar si hay permisos
      final hasPermissions =
          await _healthImporter.requestHealthConnectPermissions();

      if (!mounted) return;

      setState(() {
        _hasPermissions = hasPermissions;
        _statusMessage = hasPermissions
            ? '✓ Permisos concedidos'
            : '✗ Permisos rechazados - Abre Health Connect manualmente';
      });

      if (hasPermissions) {
        // Cargar último sincronización
        _loadLastSyncTime();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loadLastSyncTime() {
    // TODO: Implementar lectura desde SharedPreferences
    _lastSync = DateTime.now().subtract(const Duration(days: 7));
  }

  Future<void> _syncWithHevy() async {
    setState(() {
      _isSyncing = true;
      _statusMessage = 'Conectando con Hevy vía Health Connect...';
    });

    try {
      // Inicializar importador
      await _healthImporter.initialize(_healthBridge);

      // Rango de sincronización: últimos 30 días
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));

      // Sincronizar datos
      final workoutsCount = await _healthImporter.syncFromHealthConnect(
        startDate: startDate,
        endDate: endDate,
      );

      if (!mounted) return;

      // Actualizar progresión
      await _progressionService.initialize();

      setState(() {
        _workoutsImported = workoutsCount;
        _lastSync = DateTime.now();
        _isSyncing = false;
        _statusMessage = workoutsCount > 0
            ? '✓ Se importaron $workoutsCount entrenamientos'
            : '✓ Sin nuevos entrenamientos';
      });

      // Mostrar diálogo de éxito
      if (workoutsCount > 0) {
        _showSuccessDialog(workoutsCount);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _statusMessage = 'Error en sincronización: $e';
        });
      }
    }
  }

  void _showSuccessDialog(int count) {
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.neonGreen.withOpacity(0.2),
                  border: Border.all(
                    color: AppColors.neonGreen,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.neonGreen,
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '¡Sincronización Exitosa!',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neonGreen,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Se importaron $count entrenamientos desde Hevy',
                textAlign: TextAlign.center,
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child: const Text(
                  'Continuar',
                  style: TextStyle(
                    color: AppColors.rpgDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.rpgDark,
        title: const Text(
          'Sincronizar con Hevy',
          style: TextStyle(
            color: AppColors.neonGreen,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.neonGreen),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.neonGreen,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado de conexión
                  _buildConnectionStatus(),
                  const SizedBox(height: 24),

                  // Información de Health Connect
                  _buildHealthConnectInfo(),
                  const SizedBox(height: 24),

                  // Botón de sincronización
                  _buildSyncButton(),
                  const SizedBox(height: 24),

                  // Estado del último sincronización
                  if (_lastSync != null) _buildLastSyncInfo(),
                  const SizedBox(height: 24),

                  // Entrenamientos importados
                  if (_workoutsImported != null) _buildImportStats(),
                  const SizedBox(height: 24),

                  // Instrucciones
                  _buildInstructions(),
                ],
              ),
            ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _hasPermissions
            ? AppColors.neonGreen.withOpacity(0.1)
            : AppColors.neonRed.withOpacity(0.1),
        border: Border.all(
          color: _hasPermissions ? AppColors.neonGreen : AppColors.neonRed,
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _hasPermissions ? Icons.check_circle : Icons.error,
                color: _hasPermissions ? AppColors.neonGreen : AppColors.neonRed,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasPermissions
                          ? 'Conectado a Health Connect'
                          : 'No conectado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _hasPermissions
                            ? AppColors.neonGreen
                            : AppColors.neonRed,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusMessage ?? 'Verificando permisos...',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthConnectInfo() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.rpgCardDark,
        border: Border.all(
          color: AppColors.neonCyan.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.neonCyan,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Health Connect Integration',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neonCyan,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            'Sistema',
            'Android Health Connect',
            Icons.android,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Fuente de Datos',
            'Aplicación Hevy',
            Icons.fit_screen,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Datos Sincronizables',
            'Entrenamientos, Ejercicios, Calorías',
            Icons.data_usage,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.neonCyan, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSyncButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSyncing ? null : _syncWithHevy,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neonGreen,
          disabledBackgroundColor: AppColors.neonGreen.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
        ),
        icon: _isSyncing
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.rpgDark),
                ),
              )
            : const Icon(Icons.cloud_sync),
        label: Text(
          _isSyncing ? 'Sincronizando...' : 'Sincronizar con Hevy',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.rpgDark,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildLastSyncInfo() {
    final timeAgo = _lastSync!.difference(DateTime.now()).inHours.abs();
    final timeLabel = timeAgo < 1
        ? 'hace menos de 1 hora'
        : timeAgo < 24
            ? 'hace $timeAgo horas'
            : 'hace ${(timeAgo / 24).toStringAsFixed(0)} días';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.rpgCardDark,
        border: Border.all(
          color: AppColors.neonPurple.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.neonPurple,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Última Sincronización',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neonPurple,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            timeLabel,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _lastSync.toString().split('.')[0],
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportStats() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.rpgCardDark,
        border: Border.all(
          color: AppColors.neonOrange.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.neonOrange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Estadísticas de Importación',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neonOrange,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatBox(
                'Entrenamientos',
                '$_workoutsImported',
                AppColors.neonGreen,
              ),
              _buildStatBox(
                'Rango',
                '30 días',
                AppColors.neonCyan,
              ),
              _buildStatBox(
                'Estado',
                '✓ OK',
                AppColors.neonOrange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.rpgDark,
        border: Border.all(
          color: AppColors.neonMagenta.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.neonMagenta,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Cómo Sincronizar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neonMagenta,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInstructionStep(
            '1',
            'Abre la app Hevy y registra tus entrenamientos',
            Icons.fitness_center,
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(
            '2',
            'Asegúrate de que Hevy tenga acceso a Health Connect',
            Icons.health_and_safety,
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(
            '3',
            'Toca el botón "Sincronizar con Hevy"',
            Icons.cloud_sync,
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(
            '4',
            'Tus datos aparecerán en el Symmetry Engine',
            Icons.auto_awesome,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.neonMagenta.withOpacity(0.2),
            border: Border.all(
              color: AppColors.neonMagenta,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.neonMagenta,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
