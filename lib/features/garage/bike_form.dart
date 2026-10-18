import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:motohealth/core/formatting.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/shared/widgets/form_bits.dart';

/// Adds a bike, or edits [bike] when given.
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
  late final _odo = TextEditingController(
    text: widget.bike?.startOdometer.round().toString(),
  );

  @override
  void dispose() {
    for (final c in [_name, _make, _model, _year, _plate, _odo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final store = ref.read(motoStoreProvider.notifier);
    final year = int.tryParse(_year.text.trim());
    final odo = parseNumber(_odo.text) ?? 0;
    final existing = widget.bike;
    if (existing == null) {
      await store.addBike(
        Bike(
          id: newId(),
          name: _name.text.trim(),
          make: _make.text.trim(),
          model: _model.text.trim(),
          year: year,
          plate: _plate.text.trim(),
          addedOn: dayOf(DateTime.now()),
          startOdometer: odo,
          tasks: ServiceTask.defaults(),
        ),
      );
    } else {
      await store.updateBike(
        Bike(
          id: existing.id,
          name: _name.text.trim(),
          make: _make.text.trim(),
          model: _model.text.trim(),
          year: year,
          plate: _plate.text.trim(),
          addedOn: existing.addedOn,
          startOdometer: existing.startOdometer,
          tasks: existing.tasks,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _key,
      child: Column(
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
                child: TextFormField(
                  controller: _plate,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Plate'),
                ),
              ),
            ],
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
