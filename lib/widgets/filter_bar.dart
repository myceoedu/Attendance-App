import 'package:flutter/material.dart';

import '../constants/app_theme.dart';

class AppFilterOption {
  final String value;
  final String label;

  const AppFilterOption({
    required this.value,
    required this.label,
  });
}

class AppFilterBar extends StatelessWidget {
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final String searchHint;
  final List<AppFilterOption> chipOptions;
  final String? selectedChip;
  final ValueChanged<String>? onChipSelected;
  final List<Widget> extraFilters;
  final EdgeInsetsGeometry margin;

  /// Shown directly under status chips (e.g. “Showing: pending only…”).
  final Widget? belowChips;

  const AppFilterBar({
    super.key,
    this.searchController,
    this.onSearchChanged,
    this.searchHint = 'Search',
    this.chipOptions = const [],
    this.selectedChip,
    this.onChipSelected,
    this.extraFilters = const [],
    this.margin = const EdgeInsets.fromLTRB(16, 10, 16, 8),
    this.belowChips,
  });

  bool get _showSearch => searchController != null && onSearchChanged != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showSearch || chipOptions.isNotEmpty || extraFilters.isNotEmpty)
            const Text(
              'Filter & Search',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          if (_showSearch || chipOptions.isNotEmpty || extraFilters.isNotEmpty)
            const SizedBox(height: 10),
          if (_showSearch) ...[
            TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: searchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              ),
            ),
          ],
          if (_showSearch && (chipOptions.isNotEmpty || extraFilters.isNotEmpty))
            const SizedBox(height: 12),
          if (chipOptions.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in chipOptions)
                  ChoiceChip(
                    label: Text(option.label),
                    selected: selectedChip == option.value,
                    onSelected: onChipSelected == null
                        ? null
                        : (_) => onChipSelected!(option.value),
                    selectedColor: AppColors.primaryLight,
                    backgroundColor: AppColors.surface,
                    showCheckmark: false,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    side: BorderSide(
                      color: selectedChip == option.value
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      color: selectedChip == option.value
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: selectedChip == option.value
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
              ],
            ),
          if (chipOptions.isNotEmpty && belowChips != null) ...[
            const SizedBox(height: 8),
            belowChips!,
          ],
          if (chipOptions.isNotEmpty && extraFilters.isNotEmpty)
            const SizedBox(height: 10),
          if (extraFilters.isNotEmpty)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: extraFilters,
            ),
        ],
      ),
    );
  }
}

class AppFilterDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData icon;
  final String? label;
  final double width;

  const AppFilterDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
    this.label,
    this.width = 190,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: value,
                  isExpanded: true,
                  items: items,
                  onChanged: onChanged,
                  hint: label == null
                      ? null
                      : Text(
                          label!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
