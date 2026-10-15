import 'package:flutter/material.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';

/// Horizontal filtering and search control bar for saved report history.
///
/// Supports:
/// - Real-time text search input with instant clear button.
/// - Filter chips for input sources (Text, Screenshot, Link).
/// - Filter chips for analysis provenance (Local only vs Cloud AI).
class HistoryFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final InputSource? selectedSource;
  final ValueChanged<InputSource?> onSourceChanged;
  final bool? selectedProvenance;
  final ValueChanged<bool?> onProvenanceChanged;

  const HistoryFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.selectedSource,
    required this.onSourceChanged,
    required this.selectedProvenance,
    required this.onProvenanceChanged,
  });

  bool get hasActiveFilters =>
      selectedSource != null ||
      selectedProvenance != null ||
      searchController.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Input
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search reviewed text or findings...',
            prefixIcon: const Icon(Icons.search, size: 22),
            suffixIcon: searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Clear search',
                    onPressed: onClearSearch,
                  )
                : null,
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filter chips row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Source filter chips
              FilterChip(
                label: const Text('All Sources'),
                selected: selectedSource == null,
                onSelected: (_) => onSourceChanged(null),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Text'),
                avatar: const Icon(Icons.chat_bubble_outline, size: 14),
                selected: selectedSource == InputSource.messageText,
                onSelected: (selected) {
                  onSourceChanged(selected ? InputSource.messageText : null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Screenshot'),
                avatar: const Icon(Icons.image_outlined, size: 14),
                selected: selectedSource == InputSource.screenshot,
                onSelected: (selected) {
                  onSourceChanged(selected ? InputSource.screenshot : null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Link / QR'),
                avatar: const Icon(Icons.link_outlined, size: 14),
                selected: selectedSource == InputSource.link,
                onSelected: (selected) {
                  onSourceChanged(selected ? InputSource.link : null);
                },
              ),
              const SizedBox(width: 12),
              Container(height: 20, width: 1, color: theme.dividerColor),
              const SizedBox(width: 12),

              // Provenance chips
              FilterChip(
                label: const Text('All Checks'),
                selected: selectedProvenance == null,
                onSelected: (_) => onProvenanceChanged(null),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Local Only'),
                selected: selectedProvenance == false,
                onSelected: (selected) {
                  onProvenanceChanged(selected ? false : null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('AI-Assisted'),
                selected: selectedProvenance == true,
                onSelected: (selected) {
                  onProvenanceChanged(selected ? true : null);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
