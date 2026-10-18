import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:motohealth/core/theme/app_theme.dart';
import 'package:motohealth/features/ai/schedule_ai_screen.dart';
import 'package:motohealth/features/garage/maintenance_catalog.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/shared/widgets/content_width.dart';
import 'package:motohealth/shared/widgets/form_bits.dart';

/// Edit how often each maintenance job comes round for one bike.
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key, required this.bikeId});

  final String bikeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(motoStoreProvider).valueOrNull ?? const MotoData();
    final bike = data.bikes.where((b) => b.id == bikeId).firstOrNull;
    if (bike == null) return const Scaffold();
    final palette = context.palette;

    String describe(ServiceTask t) => [
      if (t.intervalKm != null) 'every ${t.intervalKm!.round()} km',
      if (t.intervalDays != null) 'every ${t.intervalDays} days',
    ].join(' or ');

    return Scaffold(
      appBar: AppBar(
        title: Text('${bike.name} schedule'),
        actions: [
          IconButton(
            tooltip: 'Let AI choose the jobs',
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ScheduleAiScreen(bikeId: bike.id),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addFromCatalog(context, ref, bike),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add job'),
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                0,
                AppSpacing.screen,
                AppSpacing.sm,
              ),
              child: Text(
                'A job falls due when either interval is reached, whichever '
                'comes first.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
              ),
            ),
            for (final t in bike.tasks)
              ListTile(
                title: Text(t.name),
                isThreeLine: t.note.isNotEmpty,
                subtitle: Text(
                  t.note.isEmpty ? describe(t) : '${describe(t)}\n${t.note}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _edit(context, ref, bike, t),
              ),
          ],
        ),
      ),
    );
  }

  /// Every catalog job the bike does not have yet, plus a custom job.
  Future<void> _addFromCatalog(BuildContext context, WidgetRef ref, Bike bike) {
    final have = {for (final t in bike.tasks) t.id};
    final missing = [
      for (final i in maintenanceCatalog)
        if (!have.contains(i.id)) i,
    ];
    return showFormSheet<void>(
      context,
      title: 'Add a job',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _edit(context, ref, bike, null);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Custom job'),
          ),
          const SizedBox(height: AppSpacing.md),
          if (missing.isEmpty)
            const Text('Every job in the catalog is already on your list.'),
          for (final category in CatalogCategory.values)
            if (missing.any((i) => i.category == category)) ...[
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(category.label, style: context.sectionLabel),
              ),
              for (final i in missing.where((i) => i.category == category))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(i.name),
                  subtitle: Text(
                    [
                      if (i.km != null) 'every ${i.km!.round()} km',
                      if (i.days != null) 'every ${i.days} days',
                      if (i.hint != 'all bikes') i.hint,
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.add_rounded),
                  onTap: () async {
                    await ref
                        .read(motoStoreProvider.notifier)
                        .updateBike(
                          bike.copyWith(tasks: [...bike.tasks, i.toTask()]),
                        );
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
            ],
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Bike bike,
    ServiceTask? task,
  ) {
    return showFormSheet<void>(
      context,
      title: task == null ? 'New job' : task.name,
      child: _TaskForm(bike: bike, task: task),
    );
  }
}

class _TaskForm extends ConsumerStatefulWidget {
  const _TaskForm({required this.bike, this.task});

  final Bike bike;
  final ServiceTask? task;

  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.task?.name);
  late final _km = TextEditingController(
    text: widget.task?.intervalKm?.round().toString(),
  );
  late final _days = TextEditingController(
    text: widget.task?.intervalDays?.toString(),
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _km.dispose();
    _days.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final km = double.tryParse(_km.text.replaceAll(',', '').trim());
    final days = int.tryParse(_days.text.trim());
    if ((km ?? 0) <= 0 && (days ?? 0) <= 0) {
      setState(() => _error = 'Set a km or a days interval.');
      return;
    }
    final task = ServiceTask(
      id: widget.task?.id ?? newId(),
      name: _name.text.trim(),
      intervalKm: (km ?? 0) > 0 ? km : null,
      intervalDays: (days ?? 0) > 0 ? days : null,
    );
    final tasks = [
      for (final t in widget.bike.tasks)
        if (t.id != task.id) t,
    ];
    final index = widget.task == null
        ? tasks.length
        : widget.bike.tasks.indexWhere((t) => t.id == task.id);
    tasks.insert(index.clamp(0, tasks.length), task);
    await ref
        .read(motoStoreProvider.notifier)
        .updateBike(widget.bike.copyWith(tasks: tasks));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, widget.task!.name)) return;
    await ref
        .read(motoStoreProvider.notifier)
        .updateBike(
          widget.bike.copyWith(
            tasks: [
              for (final t in widget.bike.tasks)
                if (t.id != widget.task!.id) t,
            ],
          ),
        );
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
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Job'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          NumberField(
            controller: _km,
            label: 'Every',
            suffix: 'km',
            required: false,
            integer: true,
          ),
          const SizedBox(height: 12),
          NumberField(
            controller: _days,
            label: 'Or every',
            suffix: 'days',
            required: false,
            integer: true,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 20),
          FormActions(
            onSave: _save,
            onDelete: widget.task == null ? null : _delete,
          ),
        ],
      ),
    );
  }
}
