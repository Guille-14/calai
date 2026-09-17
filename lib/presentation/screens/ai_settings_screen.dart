import '../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../data/services/ollama_service.dart';
import '../../data/services/google_ai_service.dart';
import '../../data/services/food_service.dart';
import '../widgets/ollama_terminal_widget.dart';

/// Screen for AI selection and configuration (Ollama & Google Gemini)
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen>
    with SingleTickerProviderStateMixin {
  final OllamaService _ollamaService = OllamaService();
  final GoogleAiService _googleService = GoogleAiService();

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _googleApiKeyController = TextEditingController();

  bool _isLoading = true;
  String _activeProvider = 'ollama';

  // Ollama states
  bool _ollamaAvailable = false;
  bool _testingConnection = false;
  bool _loadingModels = false;
  String _selectedModel = 'llava:7b';
  List<String> _installedModels = [];
  int _responseTimeMs = 0;
  List<OllamaServer> _servers = [];
  String? _selectedServerId;

  // Google states
  bool _googleAvailable = false;
  String _selectedGoogleModel = 'gemini-1.5-flash';
  List<String> _googleModels = [];
  bool _loadingGoogleModels = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    ); // Solo se anima durante el ping (antes repeat() permanente a 60fps).
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    try {
      await FoodService.initFromPrefs();
      await _ollamaService.initialize();
      await _googleService.initialize();

      if (mounted) {
        setState(() {
          _activeProvider = FoodService.activeProvider;
          _servers = _ollamaService.servers;
          _selectedServerId = _ollamaService.activeServer?.id;
          _urlController.text = _ollamaService.baseUrl;
          _selectedModel = _ollamaService.selectedModel;

          _googleApiKeyController.text = _googleService.apiKey;
          _selectedGoogleModel = _googleService.selectedModel;
        });
      }

      final ollamaAvailable = await _ollamaService.isServerAvailable();
      bool googleAvailable = false;
      if (_googleService.apiKey.isNotEmpty) {
        try {
          final resp = await _googleService.generateResponse(prompt: 'ping');
          googleAvailable = resp.isSuccess;
        } catch (e) {
          googleAvailable = false;
        }
      }

      if (mounted) {
        setState(() {
          _ollamaAvailable = ollamaAvailable;
          _googleAvailable = googleAvailable;
          _isLoading = false;
        });

        if (ollamaAvailable) {
          _loadInstalledModels();
        }
        if (googleAvailable) {
          _loadGoogleModels();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error inicializando: $e', AppColors.error);
      }
    }
  }

  Future<void> _changeProvider(String provider) async {
    await FoodService.setProvider(provider);
    setState(() {
      _activeProvider = provider;
      _responseTimeMs = 0; // Reset response time on switch
    });

    // Auto-load models if they are empty
    if (provider == 'ollama' && _installedModels.isEmpty) {
      _loadInstalledModels();
    } else if (provider == 'google' && _googleModels.isEmpty) {
      _loadGoogleModels();
    }

    _showSnackBar('Proveedor: ${provider.toUpperCase()}', AppColors.accent);
  }

  Future<void> _onServerChanged(String? serverId) async {
    if (serverId == null) return;

    // Clear models immediately to avoid showing old ones
    setState(() {
      _installedModels = [];
      _selectedServerId = serverId;
    });

    await _ollamaService.setActiveServer(serverId);
    setState(() {
      _urlController.text = _ollamaService.baseUrl;
    });
    await _testConnection();
  }

  Future<void> _loadInstalledModels() async {
    if (_loadingModels) return;
    setState(() {
      _loadingModels = true;
      _installedModels = [];
    });
    final models = await _ollamaService.getInstalledModels();
    if (mounted) {
      setState(() {
        _installedModels = models;
        _loadingModels = false;
      });
    }
  }

  Future<void> _loadGoogleModels() async {
    if (_loadingGoogleModels) return;
    setState(() {
      _loadingGoogleModels = true;
      _googleModels = [];
    });
    final models = await _googleService.getAvailableModels();
    if (mounted) {
      setState(() {
        _googleModels = models;
        _loadingGoogleModels = false;
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() => _testingConnection = true);
    _pulseController.repeat(reverse: true);
    final stopwatch = Stopwatch()..start();

    if (_activeProvider == 'ollama') {
      await _ollamaService.updateBaseUrl(_urlController.text.trim());
      try {
        // FAST CHECK: Use isServerAvailable which uses /api/tags
        final isAvailable = await _ollamaService.isServerAvailable();
        stopwatch.stop();

        if (mounted) {
          if (isAvailable) {
            setState(() {
              _ollamaAvailable = true;
              _responseTimeMs = stopwatch.elapsedMilliseconds;
            });
            _loadInstalledModels();
            _showSnackBar('✅ Ollama OK (${_responseTimeMs}ms)', AppColors.accent);
          } else {
            setState(() => _ollamaAvailable = false);
            _showSnackBar('❌ Ollama: Servidor no disponible', AppColors.error);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _ollamaAvailable = false);
          _showSnackBar('❌ Error Ollama: $e', AppColors.error);
        }
      }
    } else {
      await _googleService.updateApiKey(_googleApiKeyController.text.trim());
      try {
        final response = await _googleService.generateResponse(
          prompt: 'ping',
          model: _selectedGoogleModel,
        );
        stopwatch.stop();
        if (mounted) {
          if (response.isSuccess) {
            setState(() {
              _googleAvailable = true;
              _responseTimeMs = stopwatch.elapsedMilliseconds;
            });
            _loadGoogleModels();
            _showSnackBar('✅ Google OK (${_responseTimeMs}ms)', AppColors.accent);
          } else {
            setState(() => _googleAvailable = false);
            _showSnackBar('❌ Google: ${response.error}', AppColors.error);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _googleAvailable = false);
          _showSnackBar('❌ Error Google: $e', AppColors.error);
        }
      }
    }

    _pulseController.stop();
    if (mounted) {
      setState(() => _testingConnection = false);
    }
  }

  Future<void> _saveUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar('Introduce URL', AppColors.accent);
      return;
    }
    await _ollamaService.updateBaseUrl(url);
    _showSnackBar('URL guardada', AppColors.accent);
  }

  Future<void> _saveGoogleKey() async {
    final key = _googleApiKeyController.text.trim();
    if (key.isEmpty) {
      _showSnackBar('Introduce API Key', AppColors.accent);
      return;
    }
    await _googleService.updateApiKey(key);
    _showSnackBar('Key guardada', AppColors.accent);
  }

  Future<void> _selectModel(String model) async {
    if (_activeProvider == 'ollama') {
      await _ollamaService.updateModel(model);
      setState(() => _selectedModel = model);
    } else {
      await _googleService.updateModel(model);
      setState(() => _selectedGoogleModel = model);
    }
    _showSnackBar('Modelo: $model', AppColors.accent);
  }

  Future<void> _addOrEditServer({OllamaServer? existingServer}) async {
    final nameController = TextEditingController(text: existingServer?.name ?? '');
    final urlController = TextEditingController(text: existingServer?.url ?? '');
    ServerType selectedType = existingServer?.type ?? ServerType.local;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.elevatedCardBackground,
          title: Text(existingServer != null ? 'Editar Servidor' : 'Añadir Servidor', style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Nombre', labelStyle: TextStyle(color: Colors.white70)),
                ),
                TextField(
                  controller: urlController,
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                  decoration: const InputDecoration(labelText: 'URL (http://ip:port)', labelStyle: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _typeButton(setDialogState, ServerType.local, '🏠 Local', selectedType, (t) => selectedType = t),
                    const SizedBox(width: 8),
                    _typeButton(setDialogState, ServerType.tailscale, '🌐 Tailscale', selectedType, (t) => selectedType = t),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );

    if (result == true) {
      final newServer = OllamaServer(
        id: existingServer?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: nameController.text.trim(),
        url: urlController.text.trim().replaceAll(RegExp(r'/+$'), ''),
        type: selectedType,
      );
      if (existingServer != null) await _ollamaService.updateServer(newServer);
      else await _ollamaService.addServer(newServer);
      setState(() => _servers = _ollamaService.servers);
    }
  }

  Widget _typeButton(StateSetter setDialogState, ServerType type, String label,
      ServerType selected, ValueChanged<ServerType> onSelect) {
    final isSelected = type == selected;
    return Expanded(
      child: GestureDetector(
        // Antes mutaba el parámetro local `selected` (copia por valor) y el
        // tipo nunca cambiaba; ahora notifica a través del callback.
        onTap: () {
          onSelect(type);
          setDialogState(() {});
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent.withValues(alpha: 0.2) : AppColors.elevatedCardBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppColors.accent : Colors.transparent),
          ),
          child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ),
    );
  }

  Future<void> _deleteServer(String serverId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.elevatedCardBackground,
        title: const Text('¿Eliminar servidor?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text('Sí')),
        ],
      ),
    );
    if (confirm == true) {
      await _ollamaService.removeServer(serverId);
      setState(() {
        _servers = _ollamaService.servers;
        _selectedServerId = _ollamaService.activeServer?.id;
        _urlController.text = _ollamaService.baseUrl;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _urlController.dispose();
    _googleApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text('Inteligencia Artificial')),
        body: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('IA · Configuración'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProviderSelector(),
            const SizedBox(height: 24),
            _buildConnectionStatus(),
            const SizedBox(height: 24),
            if (_activeProvider == 'ollama') ..._buildOllamaSections()
            else ..._buildGoogleSections(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.elevatedCardBackground, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _providerBtn('ollama', 'Ollama Local', Icons.computer),
          _providerBtn('google', 'Google AI', Icons.auto_awesome),
        ],
      ),
    );
  }

  Widget _providerBtn(String id, String label, IconData icon) {
    final selected = _activeProvider == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeProvider(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : Colors.white38),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white38, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    final ready = _activeProvider == 'ollama' ? _ollamaAvailable : _googleAvailable;
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: (ready ? AppColors.accent : AppColors.error).withValues(alpha: 0.1 * _pulseAnimation.value),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: (ready ? AppColors.accent : AppColors.error).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(ready ? Icons.check_circle : Icons.error, color: ready ? AppColors.accent : AppColors.error, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ready ? 'CONECTADO Y LISTO' : 'SIN CONEXIÓN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 4),
                  if (_responseTimeMs > 0)
                    Text(
                      'Ping: ${_responseTimeMs}ms',
                      style: const TextStyle(color: AppColors.accentStrong, fontSize: 14, fontWeight: FontWeight.bold),
                    )
                  else
                    const Text('Haz ping para ver el tiempo de respuesta.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _testingConnection ? null : _testConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: _testingConnection
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('PING', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOllamaSections() {
    return [
      _buildServerSelector(),
      const SizedBox(height: 20),
      _buildModelSection(),
      const SizedBox(height: 20),
      _buildInstalledModelsSection(),
      const SizedBox(height: 20),
      _buildInfoSection(),
      const SizedBox(height: 20),
      _buildRecommendationSection(),
      const SizedBox(height: 20),
      _buildTerminalSection(),
    ];
  }

  List<Widget> _buildGoogleSections() {
    return [
      _buildGoogleConfigSection(),
      const SizedBox(height: 20),
      _buildGoogleModelSection(),
      const SizedBox(height: 20),
      _buildGoogleInfoSection(),
    ];
  }

  Widget _buildServerSelector() {
    return _section(
      icon: Icons.dns,
      title: 'Servidor Ollama',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedServerId,
            items: _servers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: _onServerChanged,
            decoration: const InputDecoration(filled: true, fillColor: AppColors.elevatedCardBackground, border: InputBorder.none),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => _addOrEditServer(), child: const Text('Añadir'))),
              // Antes usaba `_selectedServerId!` y crasheaba sin servidor seleccionado.
              IconButton(
                onPressed: _selectedServerId == null
                    ? null
                    : () => _deleteServer(_selectedServerId!),
                icon: const Icon(Icons.delete, color: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildModelSection() {
    return _section(
      icon: Icons.model_training,
      title: 'Modelo Ollama',
      child: Text(_selectedModel, style: const TextStyle(fontFamily: 'monospace', color: AppColors.accentStrong)),
    );
  }

  Widget _buildGoogleConfigSection() {
    return _section(
      icon: Icons.key,
      title: 'API Key Gemini',
      child: Column(
        children: [
          TextField(
            controller: _googleApiKeyController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Pega tu API Key de Google aquí...',
              filled: true,
              fillColor: AppColors.elevatedCardBackground,
            )
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveGoogleKey,
              icon: const Icon(Icons.save),
              label: const Text('Guardar API Key'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleModelSection() {
    final List<String> ms = _googleModels.isNotEmpty ? _googleModels : [
      'gemini-2.0-flash',
      'gemini-1.5-pro',
      'gemini-1.5-flash',
      'gemini-1.5-flash-8b'
    ];

    // Recomendación oficial para escanear comida
    const String bestForFood = 'gemini-1.5-flash';

    return _section(
      icon: Icons.psychology,
      title: 'Modelo Gemini',
      child: Column(
        children: [
          if (_loadingGoogleModels)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
            )
          else
            ...ms.map((m) {
              final isBest = m == bestForFood;
              return ListTile(
                title: Row(
                  children: [
                    Text(m, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    if (isBest) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                        child: const Text('RECOMENDADO PARA COMIDA', style: TextStyle(color: AppColors.accentStrong, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  m.contains('thinking') ? 'Pensamiento avanzado' : (m.contains('pro') ? 'Máxima Precisión' : 'Más rápido y ligero'),
                  style: TextStyle(color: m.contains('pro') ? AppColors.accent : (m.contains('thinking') ? AppColors.accent : AppColors.accentStrong), fontSize: 11),
                ),
                trailing: _selectedGoogleModel == m ? const Icon(Icons.check_circle, color: AppColors.accent) : const Icon(Icons.circle_outlined, color: Colors.white24),
                onTap: () => _selectModel(m),
              );
            }).toList(),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadGoogleModels,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Actualizar modelos', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _section({required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.elevatedCardBackground, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 18, color: AppColors.accent), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildGoogleInfoSection() {
    return _section(
      icon: Icons.info,
      title: 'Información y Registro',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Usa la potencia de la nube de Google para analizar alimentos de inmediato de forma muy rápida y precisa.', style: TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Text('👉 Obtén tu API Key gratis en: aistudio.google.com', style: TextStyle(fontSize: 12, color: AppColors.accentStrong, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInstalledModelsSection() {
    return _section(
      icon: Icons.download_done,
      title: 'Modelos en Local',
      child: Column(
        children: [
          if (_loadingModels)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
            )
          else if (_installedModels.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No hay modelos instalados o error de conexión', style: TextStyle(color: Colors.white54, fontSize: 12)),
            )
          else
            ..._installedModels.map((m) => ListTile(
              title: Text(m, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              trailing: _selectedModel == m ? const Icon(Icons.check, color: AppColors.accent) : null,
              onTap: () => _selectModel(m)
            )).toList(),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadInstalledModels,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Actualizar modelos', style: TextStyle(fontSize: 12)),
          ),
        ],
      )
    );
  }

  Widget _buildInfoSection() {
    return _section(icon: Icons.privacy_tip, title: 'Privacidad', child: const Text('Ollama mantiene tus datos en local, procesando las imágenes y chats directamente en tus equipos.', style: TextStyle(fontSize: 12, color: Colors.white70)));
  }

  Widget _buildRecommendationSection() {
    return _section(
      icon: Icons.star,
      title: 'Modelos Recomendados',
      child: Column(
        children: [
          _buildRecCard('PC Personal (Potente)', 'llama3.2-vision:11b', 'El mejor para tu RTX 3060 8GB de VRAM. Excelente visión y respuestas.'),
          const SizedBox(height: 10),
          _buildRecCard('Servidor Ubuntu (Eficiente)', 'llava:7b', 'Ideal para tu RX 580 8GB VRAM y procesador básico. Rápido y muy estable.'),
        ]
      )
    );
  }

  Widget _buildRecCard(String title, String model, String desc) {
    bool isSelected = _selectedModel == model;
    return GestureDetector(
      onTap: () async {
        // Al tocar, intentar buscar el servidor adecuado si existe.
        // Antes `orElse: () => _servers.first` crasheaba con lista vacía.
        if (_servers.isNotEmpty) {
          final server = _servers.firstWhere(
            (s) => s.name.contains('PC Personal') || s.name.contains('Local'),
            orElse: () => _servers.first,
          );
          if (_selectedServerId != server.id) {
            await _onServerChanged(server.id);
          }
        }
        await _selectModel(model);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.1) : AppColors.elevatedCardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.accent.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.computer, color: AppColors.accent.withValues(alpha: 0.8), size: 16),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: Text(model, style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                GestureDetector(
                  onTap: () => _selectModel(model),
                  child: Icon(isSelected ? Icons.check_circle : Icons.copy, color: isSelected ? AppColors.accent : Colors.white54, size: 20),
                )
              ]
            ),
            const SizedBox(height: 6),
            Text(desc, style: const TextStyle(fontSize: 11, color: Colors.white54)),
            const SizedBox(height: 8),
            Text('Comando: ollama pull $model', style: const TextStyle(fontSize: 10, color: AppColors.accentStrong, fontFamily: 'monospace')),
          ]
        )
      ),
    );
  }

  Widget _buildTerminalSection() {
    return _section(icon: Icons.terminal, title: 'Terminal', child: const OllamaTerminalWidget());
  }

  Widget _buildInfoItem(IconData icon, String title, String description) => const SizedBox(); // Placeholder to fix potential calls
}
