import 'package:flutter/material.dart';
import 'package:wufx/features/configs/models/wuwa_config.dart';

class ConfigInspectBottomSheet extends StatefulWidget {
  final WuwaConfig config;
  final VoidCallback onSelect;

  const ConfigInspectBottomSheet({
    super.key,
    required this.config,
    required this.onSelect,
  });

  @override
  State<ConfigInspectBottomSheet> createState() =>
      _ConfigInspectBottomSheetState();
}

class _ConfigInspectBottomSheetState extends State<ConfigInspectBottomSheet> {
  late Future<Map<String, String>> _contentsFuture;

  @override
  void initState() {
    super.initState();
    _contentsFuture = widget.config.readIniContents();
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
                    Icons.code_outlined,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configuration Files',
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.config.name,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.config.category,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<Map<String, String>>(
                  future: _contentsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading files: ${snapshot.error}',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      );
                    }

                    final contents = snapshot.data ?? {};
                    final fileNames = contents.keys.toList();

                    if (fileNames.isEmpty) {
                      return Center(
                        child: Text(
                          'No .ini files found in this directory.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      );
                    }

                    return DefaultTabController(
                      length: fileNames.length,
                      child: Column(
                        children: [
                          TabBar(
                            isScrollable: fileNames.length > 3,
                            dividerColor: Colors.transparent,
                            tabs: fileNames
                                .map((name) => Tab(text: name))
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: TabBarView(
                              children: fileNames.map((name) {
                                final content = contents[name] ?? '';
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      content,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onSelect();
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Select Config'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
