import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:motohealth/core/formatting.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/shared/widgets/form_bits.dart';

Future<void> showExpenseForm(
  BuildContext context, {
  required Bike bike,
  Expense? entry,
}) {
  return showFormSheet<void>(
    context,
    title: entry == null ? 'Add an expense' : 'Edit expense',
    child: _ExpenseForm(bike: bike, entry: entry),
  );
}

class _ExpenseForm extends ConsumerStatefulWidget {
  const _ExpenseForm({required this.bike, this.entry});

  final Bike bike;
  final Expense? entry;

  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm> {
  final _key = GlobalKey<FormState>();
  late DateTime _date = widget.entry?.date ?? DateTime.now();
  late ExpenseCategory _category =
      widget.entry?.category ?? ExpenseCategory.insurance;
  late final _amount = TextEditingController(
    text: widget.entry?.amount.toString(),
  );
  late final _note = TextEditingController(text: widget.entry?.note);

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    await ref
        .read(motoStoreProvider.notifier)
        .saveExpense(
          Expense(
            id: widget.entry?.id ?? newId(),
            bikeId: widget.bike.id,
            date: _date,
            category: _category,
            amount: parseNumber(_amount.text)!,
            note: _note.text.trim(),
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'this expense')) return;
    await ref.read(motoStoreProvider.notifier).deleteExpense(widget.entry!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final money = ref.watch(motoStoreProvider).valueOrNull?.currency ?? '';
    return Form(
      key: _key,
      child: Column(
        children: [
          DropdownButtonFormField<ExpenseCategory>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final c in ExpenseCategory.values)
                DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            onChanged: (c) => setState(() => _category = c ?? _category),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: NumberField(
                  controller: _amount,
                  label: 'Amount',
                  suffix: money,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DateField(
                  label: 'Date',
                  value: _date,
                  lastDate: DateTime.now(),
                  onChanged: (d) => setState(() => _date = d),
                ),
              ),
            ],
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
            onDelete: widget.entry == null ? null : _delete,
          ),
        ],
      ),
    );
  }
}
