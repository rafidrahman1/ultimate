import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:motohealth/core/formatting.dart';
import 'package:motohealth/features/garage/moto_logic.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/shared/widgets/form_bits.dart';

/// Quick odometer note, for days with no fuel or service entry.
Future<void> showOdometerForm(BuildContext context, {required Bike bike}) {
  return showFormSheet<void>(
    context,
    title: 'Log odometer',
    child: _OdometerForm(bike: bike),
  );
}

class _OdometerForm extends ConsumerStatefulWidget {
  const _OdometerForm({required this.bike});

  final Bike bike;

  @override
  ConsumerState<_OdometerForm> createState() => _OdometerFormState();
}

class _OdometerFormState extends ConsumerState<_OdometerForm> {
  final _key = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  final _km = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _km.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final data = ref.read(motoStoreProvider).requireValue;
    final km = parseNumber(_km.text)!;
    final problem = odometerProblem(data, widget.bike, _date, km);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    await ref
        .read(motoStoreProvider.notifier)
        .saveReading(
          OdometerReading(
            id: newId(),
            bikeId: widget.bike.id,
            date: _date,
            km: km,
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(motoStoreProvider).valueOrNull;
    final latest = data == null ? null : latestOdometer(data, widget.bike);
    return Form(
      key: _key,
      child: Column(
        children: [
          TextFormField(
            controller: _km,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Odometer',
              suffixText: 'km',
              helperText: latest == null
                  ? null
                  : 'Last known: ${formatKm(latest)}',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            validator: (v) =>
                (parseNumber(v ?? '') ?? 0) <= 0 ? 'Enter the odometer' : null,
          ),
          const SizedBox(height: 12),
          DateField(
            label: 'Date',
            value: _date,
            lastDate: DateTime.now(),
            onChanged: (d) => setState(() => _date = d),
          ),
          const SizedBox(height: 20),
          FormActions(onSave: _save),
        ],
      ),
    );
  }
}
