part of 'expenses_screen.dart';

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.categories,
    required this.initiallyExcluded,
  });

  final List<String> categories;
  final Set<String> initiallyExcluded;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  late final Set<String> _excluded = {...widget.initiallyExcluded};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allIncluded = _excluded.isEmpty;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: const Text('Categories counted as expenses'),
              subtitle: const Text(
                'Unchecked categories are left out of totals, charts, '
                'and AI analysis.',
              ),
              trailing: TextButton(
                onPressed: () => setState(() {
                  if (allIncluded) {
                    _excluded.addAll(widget.categories);
                  } else {
                    _excluded.clear();
                  }
                }),
                child: Text(allIncluded ? 'None' : 'All'),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: widget.categories.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No expense categories in this import.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final category in widget.categories)
                          CheckboxListTile(
                            title: Text(category),
                            value: !_excluded.contains(category),
                            onChanged: (included) => setState(() {
                              if (included ?? false) {
                                _excluded.remove(category);
                              } else {
                                _excluded.add(category);
                              }
                            }),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_excluded),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
