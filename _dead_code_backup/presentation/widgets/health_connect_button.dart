import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum HealthPlatform { appleHealth, googleFit, samsungHealth }

class HealthConnectButton extends StatelessWidget {
  final HealthPlatform platform;
  final VoidCallback? onTap;
  final bool isConnected;
  final bool isSyncing;

  const HealthConnectButton({
    super.key,
    required this.platform,
    this.onTap,
    this.isConnected = false,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSyncing ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isConnected
              ? AppColors.primaryGreen.withValues(alpha: 0.1)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isConnected
                ? AppColors.primaryGreen.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isConnected
                    ? AppColors.primaryGreen.withValues(alpha: 0.2)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: isSyncing
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryGreen,
                      ),
                    )
                  : Icon(
                      _getPlatformIcon(),
                      size: 24,
                      color: isConnected
                          ? AppColors.primaryGreen
                          : AppColors.textPrimary,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getPlatformName(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isConnected
                          ? AppColors.primaryGreen
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isConnected
                        ? 'Sincronizado'
                        : 'Conectar para importar datos',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color:
                    isConnected ? AppColors.primaryGreen : AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isConnected ? Icons.check : Icons.add,
                size: 18,
                color: isConnected ? Colors.white : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPlatformIcon() {
    switch (platform) {
      case HealthPlatform.appleHealth:
        return Icons.favorite;
      case HealthPlatform.googleFit:
        return Icons.directions_run;
      case HealthPlatform.samsungHealth:
        return Icons.sports_gymnastics;
    }
  }

  String _getPlatformName() {
    switch (platform) {
      case HealthPlatform.appleHealth:
        return 'Apple Health';
      case HealthPlatform.googleFit:
        return 'Google Fit';
      case HealthPlatform.samsungHealth:
        return 'Samsung Health';
    }
  }
}

class HealthConnectSection extends StatelessWidget {
  final bool isAppleConnected;
  final bool isGoogleConnected;
  final bool isSyncing;
  final Function(HealthPlatform)? onConnect;

  const HealthConnectSection({
    super.key,
    this.isAppleConnected = false,
    this.isGoogleConnected = false,
    this.isSyncing = false,
    this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            'Sincronizar Datos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        HealthConnectButton(
          platform: HealthPlatform.appleHealth,
          isConnected: isAppleConnected,
          isSyncing: isSyncing,
          onTap: onConnect != null
              ? () => onConnect!(HealthPlatform.appleHealth)
              : null,
        ),
        const SizedBox(height: 12),
        HealthConnectButton(
          platform: HealthPlatform.googleFit,
          isConnected: isGoogleConnected,
          isSyncing: isSyncing,
          onTap: onConnect != null
              ? () => onConnect!(HealthPlatform.googleFit)
              : null,
        ),
      ],
    );
  }
}
