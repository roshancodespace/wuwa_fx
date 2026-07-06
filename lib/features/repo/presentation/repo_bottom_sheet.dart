import 'package:flutter/material.dart';
import 'package:wufx/features/repo/services/repo_service.dart';

class RepoBottomSheet extends StatelessWidget {
  final TextEditingController urlController;
  final ValueNotifier<RepoState> repoState;
  final VoidCallback onSaveAndSync;
  final VoidCallback onResetUrl;
  final VoidCallback onCheckUpdates;
  final VoidCallback onForceRedownload;
  final VoidCallback? onViewLogs;

  const RepoBottomSheet({
    super.key,
    required this.urlController,
    required this.repoState,
    required this.onSaveAndSync,
    required this.onResetUrl,
    required this.onCheckUpdates,
    required this.onForceRedownload,
    this.onViewLogs,
  });

  String _formatLastSynced(DateTime? time) {
    if (time == null) return 'Never synced';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ValueListenableBuilder<RepoState>(
        valueListenable: repoState,
        builder: (context, state, child) {
          final colorScheme = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;
          final repoInfo = RepoService.parseGitHubUrl(urlController.text);
          final repoTitle = repoInfo != null
              ? '${repoInfo["owner"]} / ${repoInfo["repo"]}'
              : 'Custom Repository';

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_sync_outlined,
                        color: colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Repository Settings',
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              repoTitle,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (onViewLogs != null)
                        IconButton(
                          icon: const Icon(Icons.terminal_outlined),
                          tooltip: 'View Logs',
                          onPressed: () {
                            Navigator.pop(context);
                            onViewLogs!();
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(
                        Icons.commit_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Current Sync Reference',
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        state.commitSha != null
                            ? state.commitSha!.substring(0, 7)
                            : 'Unknown SHA',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          _formatLastSynced(state.lastSynced),
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (state.isSyncing) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: state.syncProgress > 0 ? state.syncProgress : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.syncStatus,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Repository Source URL',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: urlController,
                    decoration: InputDecoration(
                      hintText: 'https://github.com/owner/repo',
                      filled: true,
                      fillColor: colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.restart_alt),
                        tooltip: 'Reset to default',
                        onPressed: onResetUrl,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: state.isSyncing
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  onCheckUpdates();
                                },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          icon: const Icon(Icons.sync, size: 18),
                          label: const Text('Check Updates'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: state.isSyncing
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  onForceRedownload();
                                },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Redownload'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: state.isSyncing
                          ? null
                          : () {
                              Navigator.pop(context);
                              onSaveAndSync();
                            },
                      style: FilledButton.styleFrom(
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Save & Sync URL'),
                    ),
                  ),
                  if (onViewLogs != null) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onViewLogs!();
                        },
                        icon: const Icon(Icons.terminal_outlined, size: 16),
                        label: const Text('View Diagnostic Logs'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
