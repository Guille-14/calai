import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/symmetry/health_connect_importer.dart';
import '../screens/hevy_sync_screen.dart';

/// Widget de botón de sincronización rápida con Hevy
class HevySyncButtonWidget extends StatefulWidget {
  final VoidCallback? onSyncComplete;
  final bool showLabel;

  const HevySyncButtonWidget({
    Key? key,
    this.onSyncComplete,
    this.showLabel = true,
  }) : super(key: key);

  @override
  State<HevySyncButtonWidget> createState() => _HevySyncButtonWidgetState();
}

class _HevySyncButtonWidgetState extends State<HevySyncButtonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _syncController;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _syncController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _syncController.dispose();
    super.dispose();
  }

  Future<void> _quickSync() async {
    setState(() => _isSyncing = true);
    _syncController.repeat();

    try {
      final importer = HealthConnectImporter();
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 7));

      final count = await importer.syncFromHealthConnect(
        startDate: startDate,
        endDate: endDate,
      );

      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncController.stop();
        });

        widget.onSyncComplete?.call();

        if (count > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Sincronizados $count entrenamientos'),
              backgroundColor: AppColors.neonGreen,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncController.stop();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.neonRed,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _isSyncing ? _syncController : AlwaysStoppedAnimation(0),
      child: GestureDetector(
        onTap: _isSyncing
            ? null
            : () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const HevySyncScreen(),
                );
              },
        onLongPress: _isSyncing ? null : _quickSync,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.neonGreen.withOpacity(0.2),
                AppColors.neonCyan.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: _isSyncing
                  ? AppColors.neonGreen
                  : AppColors.neonGreen.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: _isSyncing
                ? [
                    BoxShadow(
                      color: AppColors.neonGreen.withOpacity(0.6),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isSyncing ? Icons.cloud_sync : Icons.cloud_download_outlined,
                color: AppColors.neonGreen,
                size: 18,
              ),
              if (widget.showLabel) ...[
                const SizedBox(width: 6),
                Text(
                  _isSyncing ? 'Sincronizando...' : 'Hevy Sync',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neonGreen,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
