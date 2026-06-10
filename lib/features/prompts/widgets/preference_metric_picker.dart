import 'package:flutter/material.dart';

class PreferenceMetricPicker extends StatefulWidget {
  const PreferenceMetricPicker({
    super.key,
    required this.title,
    required this.helperText,
    required this.defaultOptions,
    required this.selectedItems,
    required this.customItems,
    required this.onChanged,
    this.addFieldLabel = 'Add custom metric',
    this.addFieldHint = 'e.g. screen time',
  });

  final String title;
  final String helperText;
  final List<String> defaultOptions;
  final List<String> selectedItems;
  final List<String> customItems;
  final void Function({
    required List<String> selectedItems,
    required List<String> customItems,
  }) onChanged;
  final String addFieldLabel;
  final String addFieldHint;

  @override
  State<PreferenceMetricPicker> createState() => _PreferenceMetricPickerState();
}

class _PreferenceMetricPickerState extends State<PreferenceMetricPicker> {
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _emit({
    required List<String> selectedItems,
    required List<String> customItems,
  }) {
    widget.onChanged(selectedItems: selectedItems, customItems: customItems);
  }

  void _toggle(String item, bool selected) {
    final nextSelected = List<String>.from(widget.selectedItems);
    if (selected) {
      if (!nextSelected.contains(item)) {
        nextSelected.add(item);
      }
    } else {
      nextSelected.remove(item);
    }
    _emit(selectedItems: nextSelected, customItems: widget.customItems);
  }

  void _removeCustom(String item) {
    final nextSelected = List<String>.from(widget.selectedItems)..remove(item);
    final nextCustom = List<String>.from(widget.customItems)..remove(item);
    _emit(selectedItems: nextSelected, customItems: nextCustom);
  }

  void _addCustom() {
    final value = _customController.text.trim();
    if (value.isEmpty) return;

    final normalized = value.toLowerCase();
    final allLabels = [...widget.defaultOptions, ...widget.customItems];
    if (allLabels.any((item) => item.toLowerCase() == normalized)) {
      _customController.clear();
      return;
    }

    final nextCustom = List<String>.from(widget.customItems)..add(value);
    final nextSelected = List<String>.from(widget.selectedItems)..add(value);
    _emit(selectedItems: nextSelected, customItems: nextCustom);
    _customController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          widget.helperText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in widget.defaultOptions)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(item),
            value: widget.selectedItems.contains(item),
            onChanged: (selected) => _toggle(item, selected ?? false),
          ),
        if (widget.customItems.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Custom metrics', style: theme.textTheme.labelMedium),
          for (final item in widget.customItems)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(item),
              secondary: IconButton(
                tooltip: 'Remove custom metric',
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => _removeCustom(item),
              ),
              value: widget.selectedItems.contains(item),
              onChanged: (selected) => _toggle(item, selected ?? false),
            ),
        ],
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _customController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: widget.addFieldLabel,
                  hintText: widget.addFieldHint,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addCustom(),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: IconButton.filled(
                tooltip: 'Add metric',
                onPressed: _addCustom,
                icon: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
