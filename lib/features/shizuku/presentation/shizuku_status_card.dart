import 'package:flutter/material.dart';
import 'package:wufx/features/shizuku/services/shizuku_service.dart';

class ShizukuStatusCard extends StatelessWidget {
  const ShizukuStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ValueListenableBuilder<ShizukuState>(
      valueListenable: ShizukuService.state,
      builder: (context, state, child) {
        Color containerColor;
        Color contentColor;
        IconData icon;
        String title;
        String subtitle;

        if (state.isReady) {
          containerColor = colorScheme.secondaryContainer.withValues(
            alpha: 0.5,
          );
          contentColor = colorScheme.onSecondaryContainer;
          icon = Icons.verified_outlined;
          title = 'Shizuku Active';
          subtitle = 'Ready to apply configs & clear shader cache';
        } else if (state.isBinderRunning) {
          containerColor = colorScheme.tertiaryContainer.withValues(alpha: 0.5);
          contentColor = colorScheme.onTertiaryContainer;
          icon = Icons.security_outlined;
          title = 'Permission Required';
          subtitle = 'Shizuku is running. Please grant permission.';
        } else {
          containerColor = colorScheme.errorContainer.withValues(alpha: 0.5);
          contentColor = colorScheme.onErrorContainer;
          icon = Icons.warning_amber_rounded;
          title = 'Shizuku Not Running';
          subtitle = 'Start Shizuku on your device to apply configs.';
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: containerColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, color: contentColor, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleSmall?.copyWith(
                            color: contentColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: contentColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.isChecking || state.isBusy)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: contentColor,
                      ),
                    )
                  else if (!state.isReady)
                    TextButton(
                      onPressed: () {
                        if (!state.isBinderRunning) {
                          ShizukuService.checkStatus();
                        } else {
                          ShizukuService.requestPermission();
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: contentColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      child: Text(
                        state.isBinderRunning ? 'Grant' : 'Check',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              if (state.lastMessage != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: contentColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.lastMessage!,
                        style: textTheme.labelSmall?.copyWith(
                          color: contentColor.withValues(alpha: 0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (state.isReady) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: state.isBusy
                          ? null
                          : () => ShizukuService.forceRecompile(),
                      style: TextButton.styleFrom(
                        foregroundColor: contentColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      icon: const Icon(
                        Icons.cleaning_services_outlined,
                        size: 16,
                      ),
                      label: const Text(
                        'Force Recompile (Clear Cache)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
