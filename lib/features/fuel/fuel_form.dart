import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:motohealth/core/formatting.dart';
import 'package:motohealth/features/garage/moto_logic.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/shared/widgets/form_bits.dart';

Future<void> showFuelForm(
  BuildContext context, {
  required Bike bike,
  FuelEntry? entry,
}) {
  return showFormSheet<void>(
    context,
    title: entry == null ? 'Log a fill-up' : 'Edit fill-up',
    child: _FuelForm(bike: bike, entry: entry),
  );
}

class _FuelForm extends ConsumerStatefulWidget {
  const _FuelForm({required this.bike, this.entry});

  final Bike bike;
  final FuelEntry? entry;

  @override
  ConsumerState<_FuelForm> createState() => _FuelFormState();
}

class _FuelFormState extends ConsumerState<_FuelForm> {
  final _key = GlobalKey<FormState>();
  late DateTime _date = widget.entry?.date ?? DateTime.now();
  late bool _full = widget.entry?.fullTank ?? true;
  late FuelType? _fuelType = widget.entry?.fuelType ?? _lastFuelType();
  late final _odo = TextEditingController(
    text: widget.entry?.odometer?.round().toString(),
  );
  late final _rate = TextEditingController(
    text: widget.entry?.pricePerLitre.toStringAsFixed(2),
  );
  late final _cost = TextEditingController(text: widget.entry?.cost.toString());
  late final _station = TextEditingController(text: widget.entry?.station);
  String? _odoError;

  /// New fill-ups start with the fuel used last time.
  FuelType? _lastFuelType() {
    final data = ref.read(motoStoreProvider).valueOrNull;
    if (data == null) return null;
    for (final f in data.fuel.reversed) {
      if (f.bikeId == widget.bike.id && f.fuelType != null) return f.fuelType;
    }
    return null;
  }

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
    for (final c in [_odo, _rate, _cost, _station]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Litres follow from the total cost and the price per litre.
  double? get _litresValue {
    final rate = parseNumber(_rate.text);
    final cost = parseNumber(_cost.text);
    if (rate == null || cost == null || rate <= 0) return null;
    return cost / rate;
  }

  String? _odoValidator(String? v) {
    if ((v ?? '').trim().isEmpty) return null;
    return (parseNumber(v!) ?? 0) <= 0 ? 'Enter a number' : null;
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
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
        .saveFuel(
          FuelEntry(
            id: widget.entry?.id ?? newId(),
            bikeId: widget.bike.id,
            date: _date,
            odometer: odo,
            litres: _litresValue!,
            cost: parseNumber(_cost.text)!,
            fullTank: _full,
            station: _station.text.trim(),
            fuelType: _fuelType,
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'this fill-up')) return;
    await ref.read(motoStoreProvider.notifier).deleteFuel(widget.entry!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final money = ref.watch(motoStoreProvider).valueOrNull?.currency ?? '';
    return Form(
      key: _key,
      child: Column(
        children: [
          DateField(
            label: 'Date',
            value: _date,
            lastDate: DateTime.now(),
            onChanged: (d) => setState(() => _date = d),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _odo,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Price per litre',
                    suffixText: money,
                  ),
                  validator: (v) => (parseNumber(v ?? '') ?? 0) <= 0
                      ? 'Enter the rate'
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NumberField(
                  controller: _cost,
                  label: 'Total cost',
                  suffix: money,
                ),
              ),
            ],
          ),
          ListenableBuilder(
            listenable: Listenable.merge([_rate, _cost]),
            builder: (context, _) {
              final litres = _litresValue;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    litres == null
                        ? 'Litres: enter rate and cost'
                        : 'Litres: ${litres.toStringAsFixed(2)} L',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          SegmentedButton<FuelType>(
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: [
              for (final t in FuelType.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {?_fuelType},
            onSelectionChanged: (s) =>
                setState(() => _fuelType = s.firstOrNull),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _station,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Station (optional)'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Filled to the top'),
            subtitle: const Text('Needed to measure mileage'),
            value: _full,
            onChanged: (v) => setState(() => _full = v),
          ),
          const SizedBox(height: 8),
          FormActions(
            onSave: _save,
            onDelete: widget.entry == null ? null : _delete,
          ),
        ],
      ),
    );
  }
}
