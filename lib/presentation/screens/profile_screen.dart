import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_constants.dart';
import '../../core/symmetry/symmetry_progression_service.dart';
import '../../core/symmetry/symmetry_rank_system.dart';
import '../../core/symmetry/macro_bridge.dart';
import '../../core/utils/workout_calories.dart';
import '../../core/utils/date_key.dart';
import '../../data/local/preference_manager.dart';
import '../../data/models/user_data.dart';
import '../../data/services/ollama_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/google_fit_service.dart';
import '../../data/services/database_service.dart';
import '../../main.dart';
import 'ai_settings_screen.dart';
import '../widgets/app_skeleton.dart';

/// Perfil unificado (la fusión CalAI + Symmetry).
///
/// Antes eran dos pantallas separadas por el switcher de modos:
/// - settings_screen.dart  (datos personales, objetivos, idioma,
///   notificaciones, estado de Ollama)
/// - symmetry_profile_screen.dart (rango/XP, proteína, estado muscular,
///   reset de Symmetry)
///
/// Ahora es UNA sola pantalla con todas las secciones, porque hay una sola
/// app. El contenido se conserva textualmente de las dos originales.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ---- de settings_screen ----
  UserData? _userData;
  bool _ollamaAvailable = false;
  String _selectedLanguage = 'Español';
  bool _notificationsEnabled = true;
  final _notificationService = NotificationService();

  // ---- de symmetry_profile_screen ----
  final SymmetryProgressionService _symmetryService =
      SymmetryProgressionService();
  final MacroBridge _macroBridge = MacroBridge();

  // ---- nuevo: feedback entrenamiento -> nutrición ----
  bool _creditWorkoutCalories = false;

  // ---- Health Connect ----
  final GoogleFitService _healthService = GoogleFitService.instance;
  bool _healthConnectAvailable = false;
  bool _healthConnectAuthorized = false;
  bool _healthSyncing = false;
  Map<String, int> _workoutSourceCounts = {};
  DateTime? _lastHealthImport;
  DateTime? _healthAvailableFrom;
  DateTime? _healthAvailableTo;
  GoogleFitDailyData? _healthToday;
  HealthImportResult? _lastHealthResult;
  Map<String, int> _healthPointSources = {};
  List<Map<String, dynamic>> _healthTodayMetricRows = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefManager = PreferenceManager(prefs);
      final userData = prefManager.getUserData();

      // Estas tareas son independientes. Ejecutarlas en paralelo evita que
      // un servidor Ollama lento retrase también el perfil y Health Connect.
      final ollama = OllamaService();
      final availableFuture = () async {
        await ollama.initialize();
        return ollama.isServerAvailable();
      }();
      final notifFuture = _notificationService.isEnabled();
      final symmetryFuture = _symmetryService.initialize();
      final healthAvailableFuture = _healthService.isHealthConnectInstalled();
      final results = await Future.wait<dynamic>([
        availableFuture,
        notifFuture,
        symmetryFuture,
        healthAvailableFuture,
      ]);

      final available = results[0] as bool;
      // Idioma: main.dart lee 'language_code' ('es'/'en').
      final savedCode = prefs.getString('language_code') ?? 'es';
      final savedLang = savedCode == 'en' ? 'English' : 'Español';
      final notifEnabled = results[1] as bool;
      final healthAvailable = results[3] as bool;

      _creditWorkoutCalories = prefs.getBool(kCreditWorkoutCaloriesKey) ?? false;
      final healthAuthorized = healthAvailable
          ? await _healthService.checkAuthorization()
          : false;
      final healthToday = healthAuthorized
          ? await _healthService.fetchDailyData()
          : null;
      final database = DatabaseService();
      final databaseResults = await Future.wait<dynamic>([
        database.getWorkoutSourceCounts(),
        if (healthAuthorized)
          database.getHealthDailyMetricsBetween(DateTime.now(), DateTime.now())
        else
          Future.value(<Map<String, dynamic>>[]),
      ]);
      final sourceCounts = databaseResults[0] as Map<String, int>;
      final todayMetricRows =
          databaseResults[1] as List<Map<String, dynamic>>;
      final lastImportMs = prefs.getInt(GoogleFitService.lastImportedAtKey);

      if (mounted) {
        setState(() {
          _userData = userData;
          _ollamaAvailable = available;
          _selectedLanguage = savedLang;
          _notificationsEnabled = notifEnabled;
          _healthConnectAvailable = healthAvailable;
          _healthConnectAuthorized = healthAuthorized;
          _healthToday = healthToday;
          _workoutSourceCounts = sourceCounts;
          _healthTodayMetricRows = todayMetricRows;
          _lastHealthImport = lastImportMs == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(lastImportMs);
        });
      }
    } catch (e) {
      debugPrint('Profile: error cargando datos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncHealthHistory() async {
    if (_healthSyncing) return;
    setState(() => _healthSyncing = true);
    try {
      final result = await _healthService.importFullHistory();
      if (!mounted) return;
      if (result.isSuccess) {
        final database = DatabaseService();
        final databaseResults = await Future.wait<dynamic>([
          database.getWorkoutSourceCounts(),
          database.getHealthDailyMetricsBetween(DateTime.now(), DateTime.now()),
        ]);
        final counts = databaseResults[0] as Map<String, int>;
        final todayMetricRows =
            databaseResults[1] as List<Map<String, dynamic>>;
        final healthToday = await _healthService.fetchDailyData();
        if (!mounted) return;
        setState(() {
          _healthConnectAuthorized = true;
          _workoutSourceCounts = counts;
          _lastHealthResult = result;
          _healthPointSources = result.sourcePointCounts;
          _healthTodayMetricRows = todayMetricRows;
          _healthToday = healthToday;
          _lastHealthImport = result.lastImportedAt;
          _healthAvailableFrom = result.availableFrom;
          _healthAvailableTo = result.availableTo;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.importedWorkouts} entrenamientos importados. Los importados no dan XP.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'No se pudo sincronizar Health Connect')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sincronizando Health Connect: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _healthSyncing = false);
    }
  }

  Future<void> _toggleCreditWorkoutCalories(bool value) async {
    setState(() => _creditWorkoutCalories = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kCreditWorkoutCaloriesKey, value);
  }

  // --------------------------------------------------------------------
  // Lógica de settings_screen (conservada)
  // --------------------------------------------------------------------

  Future<void> _updateUserData(UserData newData) async {
    final prefs = await SharedPreferences.getInstance();
    final prefManager = PreferenceManager(prefs);
    await prefManager.saveUserData(newData);
    if (mounted) {
      setState(() => _userData = newData);
    }
  }

  Future<void> _showEditDialog(String field, String title, String currentValue,
      TextInputType keyboardType) async {
    final controller = TextEditingController(text: currentValue);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.elevatedCardBackground,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Ingresa $title',
            hintStyle: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.3)),
            enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.textTertiary)),
            focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Guardar',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result != null && result.isNotEmpty && _userData != null) {
      UserData updated;
      switch (field) {
        case 'weight':
          updated = _userData!
              .copyWith(weight: double.tryParse(result) ?? _userData!.weight);
          break;
        case 'height':
          updated = _userData!
              .copyWith(height: double.tryParse(result) ?? _userData!.height);
          break;
        case 'age':
          updated =
              _userData!.copyWith(age: int.tryParse(result) ?? _userData!.age);
          break;
        case 'gender':
          updated = _userData!.copyWith(gender: result);
          break;
        default:
          return;
      }
      _updateUserData(updated);
    }
  }

  Future<void> _showLanguageDialog() async {
    // Solo los idiomas realmente traducidos en AppTranslations (en/es).
    const languages = ['Español', 'English'];
    const codeByLanguage = {'Español': 'es', 'English': 'en'};

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.elevatedCardBackground,
        title: const Text('Seleccionar Idioma',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages
              .map((lang) => ListTile(
                    title:
                        Text(lang, style: const TextStyle(color: AppColors.textPrimary)),
                    trailing: _selectedLanguage == lang
                        ? const Icon(Icons.check,
                            color: AppColors.accent)
                        : null,
                    onTap: () => Navigator.pop(ctx, lang),
                  ))
              .toList(),
        ),
      ),
    );

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      final code = codeByLanguage[result] ?? 'es';
      await prefs.setString('app_language', result);
      await prefs.setString('language_code', code);
      if (mounted) {
        setState(() => _selectedLanguage = result);
        // Aplica el cambio al instante sin reiniciar la app.
        LocaleNotifier.updateLocale(Locale(code));
      }
    }
  }

  Future<void> _showGenderDialog() async {
    final genders = ['Masculino', 'Femenino', 'Otro', 'No especificado'];
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.elevatedCardBackground,
        title: const Text('Seleccionar Género',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: genders
              .map((g) => ListTile(
                    title: Text(g, style: const TextStyle(color: AppColors.textPrimary)),
                    trailing: _userData?.gender == g
                        ? const Icon(Icons.check,
                            color: AppColors.accent)
                        : null,
                    onTap: () => Navigator.pop(ctx, g),
                  ))
              .toList(),
        ),
      ),
    );

    if (result != null && _userData != null) {
      final updated = _userData!.copyWith(gender: result);
      _updateUserData(updated);
    }
  }

  void _showNotificationSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.elevatedCardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Configuración de Notificaciones',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                _buildNotifSwitch(
                    'Recordatorios de comidas',
                    'Recibe recordatorios para registrar tus comidas',
                    true,
                    (v) {}),
                _buildNotifSwitch(
                    'Alertas de objetivos',
                    'Notificaciones cuando alcances tus metas diarias',
                    true,
                    (v) {}),
                _buildNotifSwitch(
                    'Resumen semanal',
                    'Recibe un resumen de tu progreso cada semana',
                    true,
                    (v) {}),
                _buildNotifSwitch(
                    'Mensajes motivacionales',
                    'Mensajes diarios para mantener la motivación',
                    true,
                    (v) {}),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _notificationService.requestPermissions();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Permitir Notificaciones',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showReminderTimesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.elevatedCardBackground,
        title: const Text('Horario de Recordatorios',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
            'Los recordatorios se envían a las 08:00, 13:00 y 19:00',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------
  // Lógica de symmetry_profile_screen (conservada)
  // --------------------------------------------------------------------

  void _showProteinGoalDialog() {
    final controller = TextEditingController(
      text: _macroBridge.proteinGoal.toInt().toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Objetivo de Proteína',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            suffixText: 'g',
            suffixStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final goal = double.tryParse(controller.text);
              if (goal != null) {
                _symmetryService.setProteinGoal(goal);
                Navigator.pop(context);
                _loadData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Restablecer progreso?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Esta acción eliminará todo tu progreso de Symmetry, incluyendo XP, rangos e historial.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              _symmetryService.reset();
              Navigator.pop(context);
              _loadData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------
  // UI
  // --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: ScreenSkeleton(cards: 5),
      );
    }

    final progress = _symmetryService.getProgress();
    final heatMap = _symmetryService.getMuscleHeatMap();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Perfil',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildRankCard(progress),
          const SizedBox(height: 20),
          _buildProteinCard(),
          const SizedBox(height: 20),
          _buildHeatMapCard(heatMap),
          const SizedBox(height: 24),
          _buildOllamaCard(),
          const SizedBox(height: 24),
          _buildSectionHeader('INFORMACIÓN PERSONAL'),
          _buildSettingsGroup([
            _buildEditableTile(Icons.monitor_weight_outlined, 'Peso',
                '${_userData?.weight ?? 0} kg',
                () => _showEditDialog('weight', 'Peso',
                    '${_userData?.weight ?? 0}', TextInputType.number)),
            _buildEditableTile(Icons.height_outlined, 'Altura',
                '${_userData?.height ?? 0} cm',
                () => _showEditDialog('height', 'Altura',
                    '${_userData?.height ?? 0}', TextInputType.number)),
            _buildEditableTile(Icons.cake_outlined, 'Edad',
                '${_userData?.age ?? 0} años',
                () => _showEditDialog('age', 'Edad', '${_userData?.age ?? 0}',
                    TextInputType.number)),
            _buildEditableTile(Icons.wc_outlined, 'Género',
                _userData?.gender ?? 'No especificado',
                () => _showGenderDialog()),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('OBJETIVOS'),
          _buildSettingsGroup([
            _buildActionTile(Icons.flag_outlined, 'Objetivo',
                _userData?.goal ?? 'Mantener peso'),
            _buildActionTile(Icons.local_fire_department_outlined,
                'Calorías diarias',
                '${_userData?.estimatedCalories ?? 0} kcal'),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('ENTRENO'),
          _buildSettingsGroup([
            ListTile(
              leading: const Icon(Icons.bolt_outlined, color: AppColors.textSecondary),
              title: const Text('Creditar calorías quemadas',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
              subtitle: const Text(
                  'Resta el gasto estimado de cada entrenamiento del '
                  'objetivo diario (desactivado por defecto)',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              trailing: Switch(
                value: _creditWorkoutCalories,
                onChanged: _toggleCreditWorkoutCalories,
                activeThumbColor: AppColors.accent,
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('FUENTES DE DATOS'),
          _buildHealthConnectCard(),
          const SizedBox(height: 24),
          _buildSectionHeader('APLICACIÓN'),
          _buildSettingsGroup([
            _buildTapTile(Icons.language_outlined, 'Idioma', _selectedLanguage,
                _showLanguageDialog),
            _buildNotificationTile(),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('NOTIFICACIONES'),
          _buildNotificationSettings(),
          const SizedBox(height: 24),
          _buildSectionHeader('ZONA DE PELIGRO'),
          _buildSettingsGroup([
            _buildSettingsItem(
              icon: Icons.refresh,
              title: 'Restablecer progreso de Symmetry',
              subtitle: 'Borrar XP, rangos e historial de entrenamiento',
              onTap: () => _showResetDialog(),
            ),
          ]),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'v1.1.0 - Fusión CalAI + Symmetry',
              style: TextStyle(
                  color: AppColors.textPrimary.withValues(alpha: 0.2), fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHealthMetricRow() {
    final today = _healthToday;
    final values = [
      ('Pasos', today == null ? '—' : '${today.steps}', Icons.directions_walk_outlined),
      ('Calorías', today == null ? '—' : '${today.activeCalories} kcal', Icons.local_fire_department_outlined),
      ('Distancia', today == null ? '—' : '${today.distanceKm.toStringAsFixed(1)} km', Icons.route_outlined),
    ];
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.elevatedCardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(values[i].$3, size: 16, color: AppColors.accent),
                  const SizedBox(height: 4),
                  Text(values[i].$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  Text(values[i].$1, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _healthSourceLabel(String source) {
    if (source == 'mifit') return 'Mi Fitness';
    if (source == 'hevy') return 'Hevy';
    if (source == 'symmetry_app') return 'Symmetry';
    if (source.startsWith('health_connect:')) {
      return source.substring('health_connect:'.length);
    }
    return source;
  }

  String _healthMetricLabel(String key) {
    const labels = {
      'FLIGHTS_CLIMBED': 'Pisos',
      'BLOOD_OXYGEN': 'Oxígeno',
      'BODY_FAT_PERCENTAGE': 'Grasa corporal',
      'HEIGHT': 'Altura',
      'LEAN_BODY_MASS': 'Masa magra',
      'WATER': 'Agua',
      'TOTAL_CALORIES_BURNED': 'Calorías totales',
    };
    return labels[key] ?? key;
  }

  Widget _buildHealthOtherMetrics() {
    final rows = <Widget>[];
    for (final row in _healthTodayMetricRows) {
      final raw = row['other_metrics'];
      if (raw is! String || raw.isEmpty) continue;
      Map<String, dynamic> metrics;
      try {
        metrics = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        continue;
      }
      final source = _healthSourceLabel(row['source']?.toString() ?? 'unknown');
      for (final entry in metrics.entries) {
        final summary = entry.value is Map
            ? Map<String, dynamic>.from(entry.value as Map)
            : <String, dynamic>{'value': entry.value};
        final value = summary['value'];
        if (value is! num) continue;
        final unit = summary['unit']?.toString() ?? '';
        final records = (summary['records'] as num?)?.toInt() ?? 0;
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${_healthMetricLabel(entry.key)}: ${value.toStringAsFixed(1)} $unit · $source · $records registros',
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
            ),
          ),
        );
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Otros datos disponibles hoy',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildHealthConnectCard() {
    final status = !_healthConnectAvailable
        ? 'Health Connect no disponible'
        : _healthConnectAuthorized
            ? 'Conectado y autorizado'
            : 'Instalado, falta autorización';
    final imported = _workoutSourceCounts.entries
        .where((entry) => entry.key != 'native')
        .fold<int>(0, (total, entry) => total + entry.value);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (_healthConnectAvailable && _healthConnectAuthorized)
              ? AppColors.accent.withValues(alpha: 0.35)
              : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _healthConnectAuthorized
                    ? Icons.health_and_safety_outlined
                    : Icons.health_and_safety_outlined,
                color: _healthConnectAvailable
                    ? AppColors.accent
                    : AppColors.textTertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(status,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700)),
              ),
              if (_healthConnectAuthorized)
                const Icon(Icons.check_circle_outline,
                    color: AppColors.accent, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$imported entrenamientos importados · MiFit ${_workoutSourceCounts['mifit'] ?? 0} · Symmetry ${_workoutSourceCounts['symmetry_app'] ?? 0}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _buildHealthMetricRow(),
          _buildHealthOtherMetrics(),
          const SizedBox(height: 8),
          Text(
            _lastHealthResult == null
                ? 'Pulsa sincronizar para importar el histórico completo.'
                : '${_lastHealthResult!.healthDays} días · ${_lastHealthResult!.stepsRecords} pasos · ${_lastHealthResult!.activeCaloriesRecords} cal. activas · ${_lastHealthResult!.totalCaloriesRecords} cal. totales · ${_lastHealthResult!.weightRecords} pesos · ${_lastHealthResult!.sleepSessions} sueños · ${_lastHealthResult!.heartRateRecords} pulso',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
          if (_healthPointSources.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Fuentes detectadas: ${_healthPointSources.entries.map((entry) => '${entry.key} (${entry.value})').join(' · ')}',
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _lastHealthImport == null
                ? 'Todavía no se ha sincronizado el histórico.'
                : 'Última sincronización: ${formatDateKey(_lastHealthImport!)}',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          if (_healthAvailableFrom != null && _healthAvailableTo != null) ...[
            const SizedBox(height: 4),
            Text(
              'Rango recibido: ${formatDateKey(_healthAvailableFrom!)} → ${formatDateKey(_healthAvailableTo!)}',
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _healthSyncing ? null : _syncHealthHistory,
              icon: _healthSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_outlined),
              label: Text(_healthSyncing ? 'Sincronizando…' : 'Sincronizar ahora'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Los entrenamientos importados se muestran en Historial, pero no conceden XP automático para evitar duplicados.',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ---- widgets de symmetry_profile_screen ----

  Widget _buildRankCard(SymmetryProgress progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: progress.currentRank.color.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: progress.currentRank.color.withValues(alpha: 0.14),
              border: Border.all(color: progress.currentRank.color, width: 2),
            ),
            child: Center(
              child: Icon(progress.currentRank.icon,
                  color: progress.currentRank.color, size: 42),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            progress.currentRank.displayName,
            style: TextStyle(
              color: progress.currentRank.color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nivel ${progress.currentRank.level}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: progress.rankProgress,
            color: progress.currentRank.color,
            backgroundColor: AppColors.divider,
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.totalXP.toStringAsFixed(0)} XP',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              if (progress.currentRank.nextRank != null)
                Text(
                  progress.currentRank.nextRank!.displayName,
                  style: TextStyle(
                    color: progress.currentRank.nextRank!.color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProteinCard() {
    final proteinGoal = _macroBridge.proteinGoal;
    final currentProtein = _macroBridge.dailyProtein;
    final progress = _macroBridge.proteinProgress;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restaurant,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Meta de Proteína',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (_macroBridge.metProteinGoal)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'x1.2',
                    style: TextStyle(
                      color: AppColors.background,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.edit, color: AppColors.textSecondary, size: 18),
                onPressed: () => _showProteinGoalDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${currentProtein.toStringAsFixed(0)}g',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '/ ${proteinGoal.toStringAsFixed(0)}g',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            color: _macroBridge.metProteinGoal
                ? AppColors.accent
                : AppColors.accent,
            backgroundColor: AppColors.divider,
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            _macroBridge.getProteinStatusMessage(),
            style: TextStyle(
              color: _macroBridge.metProteinGoal
                  ? AppColors.accent
                  : AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatMapCard(Map<String, double> heatMap) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.map, color: AppColors.error),
              SizedBox(width: 8),
              Text(
                'Estado Muscular',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (heatMap.isEmpty)
            const Text(
              'Completa entrenamientos para ver el estado muscular',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: heatMap.entries.map((entry) {
                final color = _getFatigueColor(entry.value);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.key,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Color _getFatigueColor(double fatigue) {
    // Heatmap monocromo: el nivel se lee por intensidad, no por un color
    // diferente para recuperado, normal, fatigado o agotado.
    final intensity = (fatigue / 100).clamp(0.08, 1.0);
    return Color.lerp(AppColors.accentSubtle, AppColors.accentStrong, intensity)!;
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.textPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: onTap,
    );
  }

  // ---- widgets de settings_screen ----

  Widget _buildOllamaCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _ollamaAvailable
                ? AppColors.accent.withValues(alpha: 0.2)
                : AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (_ollamaAvailable ? AppColors.accent : AppColors.error)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _ollamaAvailable
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              color: _ollamaAvailable ? AppColors.accent : AppColors.error,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ollamaAvailable
                      ? 'IA Local Conectada'
                      : 'IA Local Desconectada',
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                ),
                Text(
                  _ollamaAvailable
                      ? 'Ollama está listo'
                      : 'Verifica conexión Tailscale',
                  style: TextStyle(
                      color: AppColors.textPrimary.withValues(alpha: 0.4), fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiSettingsScreen())),
            child: Text('CONFIGURAR',
                style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
            color: AppColors.textPrimary.withValues(alpha: 0.3),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final showDivider = entry.key < children.length - 1;
          return Column(
            children: [
              entry.value,
              if (showDivider)
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(left: 56),
                  color: AppColors.divider,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary.withValues(alpha: 0.5), size: 22),
      title: Text(title,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  color: AppColors.textPrimary.withValues(alpha: 0.4), fontSize: 14)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              color: AppColors.textPrimary.withValues(alpha: 0.2), size: 18),
        ],
      ),
      onTap: () {},
    );
  }

  Widget _buildEditableTile(
      IconData icon, String title, String value, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary.withValues(alpha: 0.5), size: 22),
      title: Text(title,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Icon(Icons.edit, color: AppColors.textPrimary.withValues(alpha: 0.3), size: 16),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildTapTile(
      IconData icon, String title, String value, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary.withValues(alpha: 0.5), size: 22),
      title: Text(title,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppColors.accent, fontSize: 14)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              color: AppColors.textPrimary.withValues(alpha: 0.2), size: 18),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildNotificationTile() {
    return ListTile(
      leading: const Icon(Icons.notifications_outlined,
          color: AppColors.textSecondary, size: 22),
      title: const Text('Notificaciones',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      trailing: Switch(
        value: _notificationsEnabled,
        onChanged: (value) async {
          await _notificationService.setEnabled(value);
          setState(() => _notificationsEnabled = value);
        },
        activeThumbColor: AppColors.accent,
      ),
      onTap: () => _showNotificationSettingsDialog(),
    );
  }

  Widget _buildNotifSwitch(
      String title, String subtitle, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              ],
            ),
          ),
          Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.accent),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.schedule, color: AppColors.textSecondary),
            title: const Text('Horario de recordatorios',
                style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('08:00, 13:00, 19:00',
                style: TextStyle(color: AppColors.textTertiary)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            onTap: _showReminderTimesDialog,
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.only(left: 56),
            color: AppColors.divider,
          ),
          ListTile(
            leading: const Icon(Icons.more_time, color: AppColors.textSecondary),
            title: const Text('Horas silenciosas',
                style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('22:00 - 08:00',
                style: TextStyle(color: AppColors.textTertiary)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
