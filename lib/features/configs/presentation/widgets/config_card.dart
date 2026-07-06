import 'package:flutter/material.dart';
import 'package:wufx/features/configs/models/wuwa_config.dart';

class ConfigCard extends StatelessWidget {
  final WuwaConfig config;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onInspect;
  final VoidCallback onApply;

  const ConfigCard({
    super.key,
    required this.config,
    required this.isSelected,
    required this.onSelect,
    required this.onInspect,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: isSelected
          ? colorScheme.secondaryContainer.withValues(alpha: 0.5)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.folder_outlined,
                color: isSelected
                    ? colorScheme.secondary
                    : colorScheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (config.parentName != null) ...[
                          Flexible(
                            child: Text(
                              '${config.parentName} / ',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            config.name,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? colorScheme.onSecondaryContainer
                                  : colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          config.category,
                          style: textTheme.labelSmall?.copyWith(
                            color: isSelected
                                ? colorScheme.onSecondaryContainer.withValues(
                                    alpha: 0.8,
                                  )
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (config.isExperimental) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• Experimental',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.code, size: 20),
                tooltip: 'Inspect .ini files',
                onPressed: onInspect,
                color: isSelected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: onApply,
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.flash_on, size: 16),
                  label: const Text(
                    'Apply',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
