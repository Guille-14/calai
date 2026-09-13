import 'package:flutter/material.dart';
import '../../core/theme/app_constants.dart';
import '../../core/utils/app_translations.dart';
import '../../data/services/food_service.dart';

class OpenRouterDiagnosticsScreen extends StatefulWidget {
  const OpenRouterDiagnosticsScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const OpenRouterDiagnosticsScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<OpenRouterDiagnosticsScreen> createState() =>
      _OpenRouterDiagnosticsScreenState();
}

class _OpenRouterDiagnosticsScreenState
    extends State<OpenRouterDiagnosticsScreen> {
  bool _isChecking = false;
  String _connectionStatus = 'Not checked';
  bool _isConnected = false;
  String _logs = '';

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isChecking = true;
      _logs = 'Starting OpenRouter diagnostics...\n';
    });

    _addLog('Model: ${FoodService.model}');
    final apiKey = FoodService.apiKey ?? '';
    // Solo longitud y últimos 4 caracteres: antes mostraba los 10 primeros
    // caracteres de la key en el log visible en pantalla.
    if (apiKey.isNotEmpty) {
      final tail = apiKey.length > 4 ? apiKey.substring(apiKey.length - 4) : '';
      _addLog('API Key: Configured (${apiKey.length} chars, ****$tail)');
    } else {
      _addLog('API Key: NOT SET');
    }
    _addLog('');

    _addLog('Step 1: Testing connection to OpenRouter...');
    final connected = await FoodService.testConnection();

    setState(() {
      _isConnected = connected;
      _connectionStatus = connected ? 'Connected' : 'Failed';
    });

    _addLog(connected ? '✓ Connection successful!' : '✗ Connection failed');
    _addLog('');

    if (connected) {
      _addLog('Step 2: Ready to analyze food images!');
      _addLog('');
      _addLog('The AI scanner is ready.');
    } else {
      _addLog('Step 2: Check your API key');
      _addLog('');
      _addLog('Make sure you have a valid OpenRouter API key.');
    }

    _addLog('');
    _addLog('Diagnostics complete.');

    setState(() {
      _isChecking = false;
    });
  }

  void _addLog(String message) {
    setState(() {
      _logs += '$message\n';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(t.translate('ai_diagnostics'),
            style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isChecking ? null : _runDiagnostics,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 20),
            _buildConfigurationCard(),
            const SizedBox(height: 20),
            _buildLogsCard(),
            const SizedBox(height: 20),
            _buildInstructionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final t = AppTranslations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isConnected ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isConnected ? Colors.green : Colors.orange,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color:
                  _isConnected ? Colors.green.shade100 : Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isConnected ? Icons.check : Icons.warning,
              size: 32,
              color: _isConnected ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isConnected
                      ? t.translate('ai_connected')
                      : t.translate('ai_not_connected'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isConnected
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isConnected
                      ? t.translate('connected')
                      : t.translate('failed'),
                  style: TextStyle(
                    color: _isConnected
                        ? Colors.green.shade600
                        : Colors.orange.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (_isChecking)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildConfigurationCard() {
    final t = AppTranslations.of(context);
    final hasKey = (FoodService.apiKey ?? '').isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.translate('configuration'), style: AppTextStyles.heading3),
          const SizedBox(height: 16),
          _buildConfigRow(t.translate('provider'), 'OpenRouter'),
          const SizedBox(height: 12),
          _buildConfigRow(t.translate('model'), FoodService.model),
          const SizedBox(height: 12),
          _buildConfigRow(
              t.translate('api_key'),
              hasKey
                  ? '${t.translate('configured')} ✓'
                  : '${t.translate('not_set')} ✗'),
        ],
      ),
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: value.contains('NOT') ? Colors.red : Colors.green,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogsCard() {
    final t = AppTranslations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                t.translate('logs'),
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_isChecking)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.green,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              child: Text(
                _logs,
                style: const TextStyle(
                  color: Color(0xFF81C784),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    final t = AppTranslations.of(context);
    final hasKey = (FoodService.apiKey ?? '').isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.translate('setup'), style: AppTextStyles.heading3),
          const SizedBox(height: 16),
          if (!hasKey) ...[
            _buildInstruction(
              '1',
              t.translate('get_api_key'),
              t.translate('get_api_key_desc'),
            ),
            _buildInstruction(
              '2',
              t.translate('add_to_env'),
              t.translate('add_to_env_desc'),
            ),
          ] else ...[
            _buildInstruction(
              '✓',
              t.translate('ready'),
              t.translate('ready_desc'),
            ),
          ],
          _buildInstruction(
            '3',
            t.translate('scan_food'),
            t.translate('scan_food_desc'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstruction(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.accentCalories.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: AppColors.accentCalories,
                  fontWeight: FontWeight.bold,
                  fontSize: number.length > 1 ? 10 : 12,
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
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
