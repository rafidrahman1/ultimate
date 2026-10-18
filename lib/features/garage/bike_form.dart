import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:motohealth/core/formatting.dart';
import 'package:motohealth/features/ai/schedule_ai_screen.dart';
import 'package:motohealth/features/garage/maintenance_catalog.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/shared/widgets/form_bits.dart';

const bikeUsages = [
  'City commuting',
  'Mixed city and highway',
  'Highway touring',
  'Off-road / trail',
  'Sport / track days',
];

/// Adds a bike, or edits [bike] when given. A new bike goes straight on to the
/// AI maintenance plan.
Future<void> showBikeForm(BuildContext context, {Bike? bike}) {
  return showFormSheet<void>(
    context,
    title: bike == null ? 'Add a bike' : 'Edit ${bike.name}',
    child: _BikeForm(bike: bike),
  );
}

class _BikeForm extends ConsumerStatefulWidget {
  const _BikeForm({this.bike});

  final Bike? bike;

  @override
  ConsumerState<_BikeForm> createState() => _BikeFormState();
}

class _BikeFormState extends ConsumerState<_BikeForm> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.bike?.name);
  late final _make = TextEditingController(text: widget.bike?.make);
  late final _model = TextEditingController(text: widget.bike?.model);
  late final _year = TextEditingController(text: widget.bike?.year?.toString());
  late final _plate = TextEditingController(text: widget.bike?.plate);
  late final _variant = TextEditingController(text: widget.bike?.variant);
  late final _cc = TextEditingController(
    text: widget.bike?.engineCc?.round().toString(),
  );
  late final _conditions = TextEditingController(text: widget.bike?.conditions);
  late final _odo = TextEditingController(
    text: widget.bike?.startOdometer.round().toString(),
  );
  late String _usage = widget.bike?.usage ?? '';

  @override
  void dispose() {
    for (final c in [
      _name,
      _make,
      _model,
      _year,
      _plate,
      _variant,
      _cc,
      _conditions,
      _odo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final store = ref.read(motoStoreProvider.notifier);
    final navigator = Navigator.of(context);
    final existing = widget.bike;
    final fields = (
      name: _name.text.trim(),
      make: _make.text.trim(),
      model: _model.text.trim(),
      year: int.tryParse(_year.text.trim()),
      plate: _plate.text.trim(),
      variant: _variant.text.trim(),
      cc: parseNumber(_cc.text),
      conditions: _conditions.text.trim(),
    );
    if (existing == null) {
      final bike = Bike(
        id: newId(),
        name: fields.name,
        make: fields.make,
        model: fields.model,
        year: fields.year,
        plate: fields.plate,
        variant: fields.variant,
        engineCc: fields.cc,
        usage: _usage,
        conditions: fields.conditions,
        addedOn: dayOf(DateTime.now()),
        startOdometer: parseNumber(_odo.text) ?? 0,
        tasks: starterTasks(),
      );
      await store.addBike(bike);
      navigator.pop();
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ScheduleAiScreen(bikeId: bike.id),
        ),
      );
    } else {
      await store.updateBike(
        Bike(
          id: existing.id,
          name: fields.name,
          make: fields.make,
          model: fields.model,
          year: fields.year,
          plate: fields.plate,
          variant: fields.variant,
          engineCc: fields.cc,
          usage: _usage,
          conditions: fields.conditions,
          addedOn: existing.addedOn,
          startOdometer: existing.startOdometer,
          tasks: existing.tasks,
        ),
      );
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nickname',
              hintText: 'e.g. Daily rider',
            ),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          Text(
            'The exact make, model and year let the AI build the right '
            'maintenance plan.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _make,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Make'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _model,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Model'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _year,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Year'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NumberField(
                  controller: _cc,
                  label: 'Engine',
                  suffix: 'cc',
                  required: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _variant,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Variant (optional)',
              hintText: 'e.g. SP, fuel injected, ABS, BS6',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _usage.isEmpty ? null : _usage,
            decoration: const InputDecoration(labelText: 'How you ride'),
            items: [
              for (final u in bikeUsages)
                DropdownMenuItem(value: u, child: Text(u)),
            ],
            onChanged: (u) => setState(() => _usage = u ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _conditions,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Conditions (optional)',
              hintText: 'e.g. humid, dusty roads, heavy traffic, short trips',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _plate,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Plate (optional)'),
          ),
          if (widget.bike == null) ...[
            const SizedBox(height: 12),
            NumberField(
              controller: _odo,
              label: 'Odometer today',
              suffix: 'km',
            ),
          ],
          const SizedBox(height: 20),
          FormActions(onSave: _save),
        ],
      ),
    );
  }
}
