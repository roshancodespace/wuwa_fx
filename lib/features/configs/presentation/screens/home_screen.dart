import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wufx/core/services/app_logger.dart';
import 'package:wufx/core/widgets/logs_bottom_sheet.dart';
import 'package:wufx/features/configs/models/wuwa_config.dart';
import 'package:wufx/features/configs/presentation/widgets/config_card.dart';
import 'package:wufx/features/configs/presentation/widgets/config_inspect_bottom_sheet.dart';
import 'package:wufx/features/repo/presentation/repo_bottom_sheet.dart';
import 'package:wufx/features/repo/services/repo_service.dart';
import 'package:wufx/features/shizuku/presentation/shizuku_status_card.dart';
import 'package:wufx/features/shizuku/services/shizuku_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _defaultRepoUrl =
      'https://github.com/Arglax/Mobile-WuWa-Config';
  static const String _key = 'repo_url';

  final TextEditingController _repoUrlController = TextEditingController();
  final ValueNotifier<RepoState> _repoState = ValueNotifier<RepoState>(
    const RepoState(),
  );

  List<WuwaConfig> _configs = [];
  String? _selectedConfigPath;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    AppLogger.i(
      'HomeScreen initialized. Loading saved settings and checking Shizuku status...',
    );
    _loadSavedSettings();
    ShizukuService.checkStatus();
  }

  @override
  void dispose() {
    _repoUrlController.dispose();
    _repoState.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_key);
    _repoUrlController.text = savedUrl ?? _defaultRepoUrl;

    final savedConfigPath = await RepoService.getSelectedConfigPath();
    if (mounted) {
      setState(() {
        _selectedConfigPath = savedConfigPath;
      });
    }

    await _syncRepository();
  }

  Future<void> _syncRepository({bool forceUpdate = false}) async {
    if (_repoState.value.isSyncing) return;

    AppLogger.i('Triggered repository sync (forceUpdate: $forceUpdate)');
    _repoState.value = _repoState.value.copyWith(
      isSyncing: true,
      syncStatus: 'Starting sync...',
      syncProgress: 0.0,
    );
    if (mounted) {
      setState(() {
        _initializing = _configs.isEmpty;
      });
    }

    final url = _repoUrlController.text.trim();
    final result = await RepoService.syncRepo(
      url,
      forceUpdate: forceUpdate,
      onProgress: (status, progress) {
        _repoState.value = _repoState.value.copyWith(
          syncStatus: status,
          syncProgress: progress,
        );
      },
    );

    AppLogger.i(
      'Sync finished. Success: ${result.success}. Status: ${result.statusMessage}. Found ${result.configs.length} configs.',
    );

    if (mounted) {
      setState(() {
        if (result.success || result.configs.isNotEmpty) {
          _configs = result.configs;
        }
        _initializing = false;
      });

      _repoState.value = _repoState.value.copyWith(
        isSyncing: false,
        syncStatus: result.statusMessage,
        commitSha: result.commitSha,
        lastSynced: result.lastSynced,
      );

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.statusMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'LOGS',
              textColor: Theme.of(context).colorScheme.onError,
              onPressed: _showLogsBottomSheet,
            ),
          ),
        );
      }
    }
  }

  void _saveRepoUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _repoUrlController.text.trim());
    AppLogger.i('Saved new repository URL: ${_repoUrlController.text.trim()}');
    _syncRepository(forceUpdate: true);
  }

  void _resetRepoUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _repoUrlController.text = _defaultRepoUrl;
    AppLogger.i('Reset repository URL to default: $_defaultRepoUrl');
    _syncRepository(forceUpdate: true);
  }

  void _selectConfig(WuwaConfig config) async {
    AppLogger.i('Selected config: "${config.name}" (${config.relativePath})');
    setState(() {
      _selectedConfigPath = config.relativePath;
    });
    await RepoService.setSelectedConfigPath(config.relativePath);
  }

  void _applyConfig(WuwaConfig config) async {
    _selectConfig(config);
    final success = await ShizukuService.applyConfig(config);
    if (!mounted) return;

    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Successfully applied "${config.name}"!'
              : (ShizukuService.state.value.lastMessage ??
                    'Failed to apply config. Check Shizuku status or logs.'),
        ),
        backgroundColor: success ? colorScheme.secondary : colorScheme.error,
        behavior: SnackBarBehavior.floating,
        action: !success
            ? SnackBarAction(
                label: 'LOGS',
                textColor: colorScheme.onError,
                onPressed: _showLogsBottomSheet,
              )
            : null,
      ),
    );
  }

  void _showInspectBottomSheet(WuwaConfig config) {
    AppLogger.i('Inspecting configuration files for "${config.name}"');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => ConfigInspectBottomSheet(
        config: config,
        onSelect: () => _selectConfig(config),
      ),
    );
  }

  void _showLogsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const LogsBottomSheet(),
    );
  }

  void _showRepoBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => RepoBottomSheet(
        urlController: _repoUrlController,
        repoState: _repoState,
        onSaveAndSync: _saveRepoUrl,
        onResetUrl: _resetRepoUrl,
        onCheckUpdates: () => _syncRepository(forceUpdate: false),
        onForceRedownload: () => _syncRepository(forceUpdate: true),
        onViewLogs: _showLogsBottomSheet,
      ),
    );
  }

  List<String> get _categories {
    final set = <String>{'All'};
    for (final c in _configs) {
      set.add(c.category);
    }
    return set.toList();
  }

  List<WuwaConfig> get _filteredConfigs {
    return _configs.where((c) {
      final matchesCat =
          _selectedCategory == 'All' || c.category == _selectedCategory;
      final matchesQuery =
          _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (c.parentName?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false) ||
          c.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<RepoState>(
      valueListenable: _repoState,
      builder: (context, repoState, child) {
        return Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            title: const Text(
              'WuFX',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            scrolledUnderElevation: 0,
            bottom: repoState.isSyncing
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(4),
                    child: LinearProgressIndicator(
                      value: repoState.syncProgress > 0
                          ? repoState.syncProgress
                          : null,
                    ),
                  )
                : null,
            actions: [
              IconButton(
                tooltip: 'View Application Logs',
                onPressed: _showLogsBottomSheet,
                icon: const Icon(Icons.terminal_outlined),
              ),
              IconButton(
                tooltip: 'Repository & Sync Settings',
                onPressed: () => _showRepoBottomSheet(context),
                icon: repoState.isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_sync_outlined),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _initializing
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    const ShizukuStatusCard(),
                    if (_configs.isNotEmpty)
                      _buildSearchAndFilters(colorScheme),
                    Expanded(
                      child: _configs.isEmpty && !repoState.isSyncing
                          ? _buildEmptyState(colorScheme)
                          : _buildConfigList(),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search configurations...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = cat;
                    });
                  },
                  showCheckmark: false,
                  backgroundColor: colorScheme.surfaceContainerLow,
                  selectedColor: colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide.none,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildConfigList() {
    final filtered = _filteredConfigs;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No configurations match your search or filter.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final config = filtered[index];
        final isSelected = config.relativePath == _selectedConfigPath;

        return ConfigCard(
          config: config,
          isSelected: isSelected,
          onSelect: () => _selectConfig(config),
          onInspect: () => _showInspectBottomSheet(config),
          onApply: () => _applyConfig(config),
        );
      },
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No configurations found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Try syncing the repository or checking your repository URL in settings.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => _syncRepository(forceUpdate: true),
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync Repository'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _showLogsBottomSheet,
                  icon: const Icon(Icons.terminal_outlined),
                  label: const Text('View Logs'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
