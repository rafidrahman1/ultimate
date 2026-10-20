import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:motohealth/core/formatting.dart';
import 'package:motohealth/features/garage/moto_logic.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/shared/widgets/form_bits.dart';

/// Logs a service visit or repair. [presetTaskId] ticks one scheduled job.
Future<void> showServiceForm(
  BuildContext context, {
  required Bike bike,
  ServiceEntry? entry,
  String? presetTaskId,
}) {
  return showFormSheet<void>(
    context,
    title: entry == null ? 'Log service' : 'Edit service',
    child: _ServiceForm(bike: bike, entry: entry, presetTaskId: presetTaskId),
  );
}

class _ServiceForm extends ConsumerStatefulWidget {
  const _ServiceForm({required this.bike, this.entry, this.presetTaskId});

  final Bike bike;
  final ServiceEntry? entry;
  final String? presetTaskId;

  @override
  ConsumerState<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends ConsumerState<_ServiceForm> {
  final _key = GlobalKey<FormState>();
  late DateTime _date = widget.entry?.date ?? DateTime.now();
  late final Set<String> _tasks = {
    ...?widget.entry?.taskIds,
    if (widget.presetTaskId != null) widget.presetTaskId!,
  };
  late final _title = TextEditingController(text: widget.entry?.title);
  late final _odo = TextEditingController(
    text: widget.entry?.odometer?.round().toString(),
  );
  late final _cost = TextEditingController(text: widget.entry?.cost.toString());
  late final _shop = TextEditingController(text: widget.entry?.shop);
  late final _notes = TextEditingController(text: widget.entry?.notes);
  String? _odoError;

  @override
  void initState() {
    super.initState();
    if (widget.entry == null) {
      final data = ref.read(motoStoreProvider).valueOrNull;
      if (data != null) {
        _odo.text = latestOdometer(data, widget.bike).round().toString();
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _odo, _cost, _shop, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _autoTitle {
    final names = [
      for (final t in widget.bike.tasks)
        if (_tasks.contains(t.id)) t.name,
    ];
    return names.join(', ');
  }

  String? _odoValidator(String? v) {
    if ((v ?? '').trim().isEmpty) return null;
    return (parseNumber(v!) ?? 0) <= 0 ? 'Enter a number' : null;
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final title = _title.text.trim().isEmpty ? _autoTitle : _title.text.trim();
    if (title.isEmpty) {
      setState(() => _odoError = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a job or type what was done.')),
      );
      return;
    }
    final data = ref.read(motoStoreProvider).requireValue;
    final odo = parseNumber(_odo.text);
    final problem = odo == null
        ? null
        : odometerProblem(
            data,
            widget.bike,
            _date,
            odo,
            exceptId: widget.entry?.id,
          );
    if (problem != null) {
      setState(() => _odoError = problem);
      return;
    }
    await ref
        .read(motoStoreProvider.notifier)
        .saveService(
          ServiceEntry(
            id: widget.entry?.id ?? newId(),
            bikeId: widget.bike.id,
            date: _date,
            odometer: odo,
            title: title,
            cost: parseNumber(_cost.text) ?? 0,
            taskIds: _tasks.toList(),
            shop: _shop.text.trim(),
            notes: _notes.text.trim(),
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'this service')) return;
    await ref.read(motoStoreProvider.notifier).deleteService(widget.entry!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final money = ref.watch(motoStoreProvider).valueOrNull?.currency ?? '';
    return Form(
      key: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DateField(
            label: 'Date',
            value: _date,
            lastDate: DateTime.now(),
            onChanged: (d) => setState(() => _date = d),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _odo,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Odometer (optional)',
                    suffixText: 'km',
                    errorText: _odoError,
                  ),
                  onChanged: (_) {
                    if (_odoError != null) setState(() => _odoError = null);
                  },
                  validator: _odoValidator,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NumberField(
                  controller: _cost,
                  label: 'Cost',
                  suffix: money,
                  required: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Jobs done (resets their countdown)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final t in widget.bike.tasks)
                FilterChip(
                  label: Text(t.name),
                  selected: _tasks.contains(t.id),
                  onSelected: (on) => setState(
                    () => on ? _tasks.add(t.id) : _tasks.remove(t.id),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'What was done',
              hintText: _autoTitle.isEmpty
                  ? 'e.g. Clutch cable replaced'
                  : _autoTitle,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _shop,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Workshop (optional)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          const SizedBox(height: 20),
          FormActions(
            onSave: _save,
            onDelete: widget.entry == null ? null : _delete,
          ),
        ],
      ),
    );
  }
}
