import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wufx/core/services/app_logger.dart';

class LogsBottomSheet extends StatelessWidget {
  const LogsBottomSheet({super.key});

  void _copyAllLogs(BuildContext context, List<LogEntry> logs) {
    if (logs.isEmpty) return;
    final buffer = StringBuffer();
    for (final log in logs) {
      final prefix = log.level == LogLevel.error
          ? '[ERROR]'
          : log.level == LogLevel.warning
          ? '[WARN]'
          : '[INFO]';
      buffer.writeln('$prefix ${log.formattedTime} - ${log.message}');
      if (log.details != null && log.details!.isNotEmpty) {
        buffer.writeln('  Details: ${log.details}');
      }
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All logs copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.terminal_outlined,
                    color: colorScheme.tertiary,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'System Diagnostics',
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.tertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Application Logs',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Clear Logs',
                    onPressed: () => AppLogger.clear(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ValueListenableBuilder<List<LogEntry>>(
                  valueListenable: AppLogger.logsNotifier,
                  builder: (context, logs, child) {
                    if (logs.isEmpty) {
                      return Center(
                        child: Text(
                          'No logs recorded yet.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        Color badgeColor;
                        Color textColor;
                        String badgeText;

                        switch (log.level) {
                          case LogLevel.error:
                            badgeColor = colorScheme.errorContainer;
                            textColor = colorScheme.onErrorContainer;
                            badgeText = 'ERR';
                            break;
                          case LogLevel.warning:
                            badgeColor = colorScheme.tertiaryContainer;
                            textColor = colorScheme.onTertiaryContainer;
                            badgeText = 'WARN';
                            break;
                          case LogLevel.info:
                            badgeColor = colorScheme.secondaryContainer;
                            textColor = colorScheme.onSecondaryContainer;
                            badgeText = 'INFO';
                            break;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      badgeText,
                                      style: textTheme.labelSmall?.copyWith(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    log.formattedTime,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                log.message,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (log.details != null &&
                                  log.details!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SelectableText(
                                    log.details!,
                                    style: textTheme.bodySmall?.copyWith(
                                      fontFamily: 'monospace',
                                      color: colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<List<LogEntry>>(
                valueListenable: AppLogger.logsNotifier,
                builder: (context, logs, child) {
                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: logs.isEmpty
                          ? null
                          : () => _copyAllLogs(context, logs),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy All Logs to Clipboard'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
