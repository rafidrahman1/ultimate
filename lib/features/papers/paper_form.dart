import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/shared/widgets/form_bits.dart';

Future<void> showPaperForm(
  BuildContext context, {
  required Bike bike,
  Paper? paper,
}) {
  return showFormSheet<void>(
    context,
    title: paper == null ? 'Add a document' : 'Edit ${paper.type.label}',
    child: _PaperForm(bike: bike, paper: paper),
  );
}

class _PaperForm extends ConsumerStatefulWidget {
  const _PaperForm({required this.bike, this.paper});

  final Bike bike;
  final Paper? paper;

  @override
  ConsumerState<_PaperForm> createState() => _PaperFormState();
}

class _PaperFormState extends ConsumerState<_PaperForm> {
  late PaperType _type = widget.paper?.type ?? PaperType.registration;
  late DateTime _expiry =
      widget.paper?.expiry ?? _after(PaperType.registration.typicalMonths);
  bool _expiryPicked = false;

  static DateTime _after(int months) {
    final now = DateTime.now();
    return DateTime(now.year, now.month + months, now.day);
  }

  late final _number = TextEditingController(text: widget.paper?.number);
  late final _note = TextEditingController(text: widget.paper?.note);

  @override
  void dispose() {
    _number.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(motoStoreProvider.notifier)
        .savePaper(
          Paper(
            id: widget.paper?.id ?? newId(),
            bikeId: widget.bike.id,
            type: _type,
            expiry: dayOf(_expiry),
            number: _number.text.trim(),
            note: _note.text.trim(),
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'this document')) return;
    await ref.read(motoStoreProvider.notifier).deletePaper(widget.paper!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<PaperType>(
          isExpanded: true,
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Document'),
          items: [
            for (final t in {...PaperType.choices, _type})
              DropdownMenuItem(value: t, child: Text(t.label)),
          ],
          onChanged: (t) => setState(() {
            _type = t ?? _type;
            // A new document gets the usual validity unless a date was chosen.
            if (widget.paper == null && !_expiryPicked) {
              _expiry = _after(_type.typicalMonths);
            }
          }),
        ),
        const SizedBox(height: 12),
        DateField(
          label: 'Expires on',
          value: _expiry,
          firstDate: DateTime(2000),
          onChanged: (d) => setState(() {
            _expiry = d;
            _expiryPicked = true;
          }),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _number,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Document / policy number (optional)',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        const SizedBox(height: 20),
        FormActions(
          onSave: _save,
          onDelete: widget.paper == null ? null : _delete,
        ),
      ],
    );
  }
}
