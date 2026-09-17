import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/app_translations.dart';
import '../../core/utils/calorie_calculator.dart';
import '../../data/local/preference_manager.dart';
import '../../data/models/user_data.dart';
import '../../data/services/ollama_service.dart';
import '../../data/services/notification_service.dart';
import '../../main.dart';
import 'ai_settings_screen.dart';
import '../../core/theme/app_constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserData? _userData;
  bool _isLoading = true;
  bool _ollamaAvailable = false;
  String _selectedLanguage = 'Español';
  bool _notificationsEnabled = true;
  final _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final prefManager = PreferenceManager(prefs);
    final userData = prefManager.getUserData();

    final ollama = OllamaService();
    await ollama.initialize();
    final available = await ollama.isServerAvailable();

    // Idioma: main.dart lee 'language_code' ('es'/'en'). Antes este ajuste
    // guardaba 'app_language' con el nombre completo y no tenía efecto.
    final savedCode = prefs.getString('language_code') ?? 'es';
    final savedLang = savedCode == 'en' ? 'English' : 'Español';
    final notifEnabled = await _notificationService.isEnabled();

    if (mounted) {
      setState(() {
        _userData = userData;
        _ollamaAvailable = available;
        _selectedLanguage = savedLang;
        _notificationsEnabled = notifEnabled;
        _isLoading = false;
      });
    }
  }

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
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Ingresa $title',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.accentCalories)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Guardar',
                style: TextStyle(color: AppColors.accentCalories)),
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
    // Antes ofrecía 5 idiomas y solo existían 2 traducciones.
    const languages = ['Español', 'English'];
    const codeByLanguage = {'Español': 'es', 'English': 'en'};

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Seleccionar Idioma',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages
              .map((lang) => ListTile(
                    title:
                        Text(lang, style: const TextStyle(color: Colors.white)),
                    trailing: _selectedLanguage == lang
                        ? const Icon(Icons.check,
                            color: AppColors.accentCalories)
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator()));
    }
    final t = AppTranslations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Ajustes',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildOllamaCard(),
          const SizedBox(height: 24),
          _buildSectionHeader('INFORMACIÓN PERSONAL'),
          _buildSettingsGroup([
            _buildEditableTile(
                Icons.monitor_weight_outlined,
                'Peso',
                '${_userData?.weight ?? 0} kg',
                () => _showEditDialog('weight', 'Peso',
                    '${_userData?.weight ?? 0}', TextInputType.number)),
            _buildEditableTile(
                Icons.height_outlined,
                'Altura',
                '${_userData?.height ?? 0} cm',
                () => _showEditDialog('height', 'Altura',
                    '${_userData?.height ?? 0}', TextInputType.number)),
            _buildEditableTile(
                Icons.cake_outlined,
                'Edad',
                '${_userData?.age ?? 0} años',
                () => _showEditDialog('age', 'Edad', '${_userData?.age ?? 0}',
                    TextInputType.number)),
            _buildEditableTile(
                Icons.wc_outlined,
                'Género',
                _userData?.gender ?? 'No especificado',
                () => _showGenderDialog()),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('OBJETIVOS'),
          _buildSettingsGroup([
            _buildActionTile(Icons.flag_outlined, 'Objetivo',
                _userData?.goal ?? 'Mantener peso'),
            _buildActionTile(
                Icons.local_fire_department_outlined,
                'Calorías diarias',
                '${_userData?.estimatedCalories ?? 0} kcal'),
          ]),
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
          const SizedBox(height: 48),
          Center(
            child: Text(
              'v1.0.3 (build 3)',
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _showGenderDialog() async {
    final genders = ['Masculino', 'Femenino', 'Otro', 'No especificado'];
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Seleccionar Género',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: genders
              .map((g) => ListTile(
                    title: Text(g, style: const TextStyle(color: Colors.white)),
                    trailing: _userData?.gender == g
                        ? const Icon(Icons.check,
                            color: AppColors.accentCalories)
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

  Widget _buildOllamaCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _ollamaAvailable
                ? AppColors.accentCalories.withValues(alpha: 0.2)
                : Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (_ollamaAvailable ? AppColors.accentCalories : Colors.red)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _ollamaAvailable
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              color: _ollamaAvailable ? AppColors.accentCalories : Colors.red,
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
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  _ollamaAvailable
                      ? 'Ollama está listo'
                      : 'Verifica conexión Tailscale',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AiSettingsScreen())),
            child: Text('CONFIGURAR',
                style: TextStyle(
                    color: AppColors.accentCalories,
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
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final showDivider = entry.key < children.length - 1;
          return Column(
            children: [
              entry.value,
              if (showDivider)
                Divider(
                    color: Colors.white.withValues(alpha: 0.05),
                    height: 1,
                    indent: 56),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 22),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.2), size: 18),
        ],
      ),
      onTap: () {},
    );
  }

  Widget _buildEditableTile(
      IconData icon, String title, String value, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 22),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppColors.accentCalories,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Icon(Icons.edit, color: Colors.white.withValues(alpha: 0.3), size: 16),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildTapTile(
      IconData icon, String title, String value, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 22),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppColors.accentCalories, fontSize: 14)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.2), size: 18),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildNotificationTile() {
    return ListTile(
      leading: const Icon(Icons.notifications_outlined,
          color: Colors.white54, size: 22),
      title: const Text('Notificaciones',
          style: TextStyle(color: Colors.white, fontSize: 15)),
      trailing: Switch(
        value: _notificationsEnabled,
        onChanged: (value) async {
          await _notificationService.setEnabled(value);
          setState(() => _notificationsEnabled = value);
        },
        activeThumbColor: AppColors.accentCalories,
      ),
      onTap: () => _showNotificationSettingsDialog(),
    );
  }

  void _showNotificationSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
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
                        color: Colors.white,
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
                      backgroundColor: AppColors.accentCalories,
                      foregroundColor: Colors.black,
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
                    style: const TextStyle(color: Colors.white, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.accentCalories),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.schedule, color: Colors.white54),
            title: const Text('Horario de recordatorios',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('08:00, 13:00, 19:00',
                style: TextStyle(color: Colors.white38)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white24),
            onTap: _showReminderTimesDialog,
          ),
          const Divider(color: Colors.white12, height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.more_time, color: Colors.white54),
            title: const Text('Horas silenciosas',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('22:00 - 08:00',
                style: TextStyle(color: Colors.white38)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white24),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  void _showReminderTimesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Horario de Recordatorios',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Los recordatorios se envían a las 08:00, 13:00 y 19:00',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar',
                style: TextStyle(color: AppColors.accentCalories)),
          ),
        ],
      ),
    );
  }
}
