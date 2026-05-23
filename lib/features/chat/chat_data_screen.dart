import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../widgets/status_message.dart';
import 'chat_data_service.dart';

class ChatDataScreen extends ConsumerStatefulWidget {
  const ChatDataScreen({super.key});

  @override
  ConsumerState<ChatDataScreen> createState() => _ChatDataScreenState();
}

class _ChatDataScreenState extends ConsumerState<ChatDataScreen> {
  final _controller = TextEditingController();
  bool _dirty = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(chatDataProvider);

    ref.listen(chatDataProvider, (_, next) {
      final data = next.valueOrNull;
      if (data == null || _dirty) return;
      _controller.text = data.content;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: () async {
              await ref.read(chatDataProvider.notifier).clear();
              if (!mounted) return;
              setState(() => _dirty = false);
            },
          ),
        ],
      ),
      body: chatAsync.when(
        data: (chatData) {
          if (_controller.text.isEmpty && !_dirty && chatData.content.isNotEmpty) {
            _controller.text = chatData.content;
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Paste your chat context for analysis.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (chatData.updatedAt != null)
                Text(
                  'Last updated: ${DateFormat('d MMM yyyy, HH:mm').format(chatData.updatedAt!.toLocal())}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                minLines: 14,
                maxLines: 24,
                decoration: const InputDecoration(
                  hintText: 'Paste chat messages or notes here...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await ref
                      .read(chatDataProvider.notifier)
                      .saveContent(_controller.text.trim());
                  if (!mounted) return;
                  setState(() => _dirty = false);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Chat data saved')),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save chat data'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StatusMessage(
          icon: Icons.error_outline,
          title: 'Could not load chat data',
          subtitle: error.toString(),
        ),
      ),
    );
  }
}
