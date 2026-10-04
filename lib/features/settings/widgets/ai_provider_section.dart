import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/shared/widgets/app_card.dart';

/// Collapsible key + model editor for one AI provider, with a status chip
/// and a connection test.
class AiProviderSection extends StatefulWidget {
  const AiProviderSection({
    super.key,
    required this.title,
    required this.icon,
    required this.keyLabel,
    required this.keyHint,
    required this.modelLabel,
    required this.keyController,
    required this.modelController,
    required this.isActive,
    required this.onChanged,
    required this.onTest,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final String keyLabel;
  final String keyHint;
  final String modelLabel;
  final TextEditingController keyController;
  final TextEditingController modelController;
  final bool isActive;
  final VoidCallback onChanged;

  /// Returns null on success, or a short error message.
  final Future<String?> Function() onTest;
  final bool initiallyExpanded;

  @override
  State<AiProviderSection> createState() => _AiProviderSectionState();
}

class _AiProviderSectionState extends State<AiProviderSection> {
  bool _obscure = true;
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final error = await widget.onTest();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = error == null;
      _testResult = error ?? 'Connection works';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = context.statusColors;

    return AppCard(
      tier: AppCardTier.flat,
      padding: EdgeInsets.zero,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: widget.initiallyExpanded || widget.isActive,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 2,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          leading: Icon(widget.icon, color: theme.colorScheme.primary),
          title: Text(widget.title, style: theme.textTheme.titleSmall),
          subtitle: ListenableBuilder(
            listenable: widget.keyController,
            builder: (context, _) {
              final hasKey = widget.keyController.text.trim().isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    _StatusChip(
                      label: hasKey ? 'Key saved' : 'No key',
                      color: hasKey ? status.good : status.neutral,
                      icon: hasKey
                          ? Icons.check_circle_outline_rounded
                          : Icons.remove_circle_outline_rounded,
                    ),
                    if (widget.isActive)
                      _StatusChip(
                        label: 'Active',
                        color: theme.colorScheme.primary,
                        icon: Icons.bolt_rounded,
                      ),
                  ],
                ),
              );
            },
          ),
          children: [
            TextField(
              controller: widget.keyController,
              decoration: InputDecoration(
                labelText: widget.keyLabel,
                hintText: widget.keyHint,
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show key' : 'Hide key',
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => widget.onChanged(),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: widget.modelController,
              decoration: InputDecoration(labelText: widget.modelLabel),
              autocorrect: false,
              onChanged: (_) => widget.onChanged(),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check_rounded, size: 18),
                  label: Text(_testing ? 'Testing…' : 'Test connection'),
                ),
                const SizedBox(width: AppSpacing.md),
                if (_testResult != null)
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _testResult!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _testOk ? status.good : status.critical,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
