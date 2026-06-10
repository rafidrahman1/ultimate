import 'package:flutter/material.dart';

import 'package:personal/features/prompts/prompt_template_sections.dart';
import 'package:personal/features/prompts/widgets/preference_metric_picker.dart';

class CrossDomainImpactPicker extends StatelessWidget {
  const CrossDomainImpactPicker({
    super.key,
    required this.selectedImpacts,
    required this.customImpacts,
    required this.onChanged,
  });

  final List<String> selectedImpacts;
  final List<String> customImpacts;
  final void Function({
    required List<String> selectedImpacts,
    required List<String> customImpacts,
  }) onChanged;

  @override
  Widget build(BuildContext context) {
    return PreferenceMetricPicker(
      title: 'Cross-domain impact metrics',
      helperText:
          'Choose which measurable impacts the assistant should connect to '
          'calendar, travel, and lifestyle disruptions. Uncheck defaults or add '
          'your own.',
      defaultOptions: PromptTemplateSections.defaultCrossDomainImpacts,
      selectedItems: selectedImpacts,
      customItems: customImpacts,
      onChanged: ({required selectedItems, required customItems}) {
        onChanged(selectedImpacts: selectedItems, customImpacts: customItems);
      },
    );
  }
}
