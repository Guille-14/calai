import '../../core/theme/app_theme.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/services/ollama_service.dart';

class OllamaTerminalWidget extends StatefulWidget {
  const OllamaTerminalWidget({super.key});

  @override
  State<OllamaTerminalWidget> createState() => _OllamaTerminalWidgetState();
}

class _OllamaTerminalWidgetState extends State<OllamaTerminalWidget> {
  final OllamaService _ollamaService = OllamaService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<TerminalEntry> _history = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _history.add(TerminalEntry(
      content: 'Ollama Remote Terminal v1.0\nEscribe "help" para comandos disponibles.',
      type: EntryType.info,
    ));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleCommand(String input) async {
    final cmd = input.trim();
    if (cmd.isEmpty) return;

    setState(() {
      _history.add(TerminalEntry(content: '> $cmd', type: EntryType.command));
      _isProcessing = true;
    });
    _inputController.clear();
    _scrollToBottom();

    final parts = cmd.split(' ');
    final action = parts[0].toLowerCase();

    try {
      switch (action) {
        case 'help':
          _addInfo('Comandos disponibles:\n'
              '- ls: Lista modelos instalados\n'
              '- ps: Modelos activos en memoria\n'
              '- pull [nombre]: Descarga un modelo\n'
              '- rm [nombre]: Elimina un modelo\n'
              '- clear: Limpia la terminal\n'
              '- exit: Cerrar terminal');
          break;
        case 'ls':
          final models = await _ollamaService.getInstalledModels();
          _addInfo(models.isEmpty ? 'No hay modelos instalados.' : 'Modelos instalados:\n${models.join("\n")}');
          break;
        case 'ps':
          final running = await _ollamaService.getRunningModels();
          _addInfo(running.isEmpty ? 'No hay modelos cargados en memoria.' : 'Modelos activos:\n${running.join("\n")}');
          break;
        case 'clear':
          setState(() {
            _history.clear();
            _history.add(TerminalEntry(content: 'Terminal reiniciada.', type: EntryType.info));
          });
          break;
        case 'pull':
          if (parts.length < 2) {
            _addError('Uso: pull [nombre_modelo]');
          } else {
            final modelName = parts[1];
            _addInfo('Iniciando descarga de $modelName...');
            await for (final status in _ollamaService.pullModel(modelName)) {
              // Una descarga dura minutos: si el usuario cierra la terminal
              // mientras tanto, seguir llamando a setState sobre un widget
              // desmontado tumba la app.
              if (!mounted) return;
              setState(() {
                if (_history.isNotEmpty && _history.last.content.startsWith('Status:')) {
                  _history.removeLast();
                }
                _history.add(TerminalEntry(content: 'Status: $status', type: EntryType.info));
              });
              _scrollToBottom();
            }
            _addInfo('Proceso finalizado.');
          }
          break;
        case 'rm':
          if (parts.length < 2) {
            _addError('Uso: rm [nombre_modelo]');
          } else {
            final success = await _ollamaService.deleteModel(parts[1]);
            success ? _addInfo('Modelo eliminado.') : _addError('Error eliminando modelo.');
          }
          break;
        default:
          _addError('Comando no reconocido: $action. Escribe "help" para ayuda.');
      }
    } catch (e) {
      _addError('Excepción: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        _scrollToBottom();
      }
    }
  }

  // Ambos se llaman después de awaits (consultas a Ollama que pueden tardar
  // o expirar), así que comprueban que el widget siga montado.
  void _addInfo(String msg) {
    if (!mounted) return;
    setState(() => _history.add(TerminalEntry(content: msg, type: EntryType.info)));
  }

  void _addError(String msg) {
    if (!mounted) return;
    setState(() => _history.add(TerminalEntry(content: msg, type: EntryType.error)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: AppColors.elevatedCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, color: AppColors.accentStrong, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'OLLAMA REMOTE CONSOLE',
                  style: TextStyle(
                    color: AppColors.accentStrong,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (_isProcessing)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentStrong),
                    ),
                  ),
              ],
            ),
          ),
          // History
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final entry = _history[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    entry.content,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 13,
                      color: _getColorForType(entry.type),
                    ),
                  ),
                );
              },
            ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                const Text('>', style: TextStyle(color: AppColors.accentStrong, fontFamily: 'Courier')),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    onSubmitted: _handleCommand,
                    enabled: !_isProcessing,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Courier',
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Ingrese comando...',
                      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForType(EntryType type) {
    switch (type) {
      case EntryType.command:
        return AppColors.textPrimary;
      case EntryType.info:
        return AppColors.accentStrong.withValues(alpha: 0.9);
      case EntryType.error:
        return AppColors.error;
    }
  }
}

enum EntryType { command, info, error }

class TerminalEntry {
  final String content;
  final EntryType type;

  TerminalEntry({required this.content, required this.type});
}
