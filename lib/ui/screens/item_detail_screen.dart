import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/lost_item_repository.dart';
import '../../models/lost_item.dart';
import '../../state/item_actions_controller.dart';
import '../widgets/lost_item_card.dart';
import '../widgets/status_badge.dart';
import 'item_form_screen.dart';

enum ItemDetailResult { updated, markedAsFound, deleted }

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key, required this.item});

  final LostItem item;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          ItemActionsController(context.read<LostItemRepository>(), item),
      child: const _ItemDetailView(),
    );
  }
}

class _ItemDetailView extends StatefulWidget {
  const _ItemDetailView();

  @override
  State<_ItemDetailView> createState() => _ItemDetailViewState();
}

class _ItemDetailViewState extends State<_ItemDetailView> {
  late final ItemActionsController _controller;
  bool _hasClosed = false;

  @override
  void initState() {
    super.initState();
    _controller = context.read<ItemActionsController>();
    _controller.addListener(_closeOnSuccess);
  }

  @override
  void dispose() {
    _controller.removeListener(_closeOnSuccess);
    super.dispose();
  }

  void _closeOnSuccess() {
    if (_controller.status != ActionStatus.success || _hasClosed) {
      return;
    }
    _hasClosed = true;
    final result = _controller.action == ItemAction.delete
        ? ItemDetailResult.deleted
        : ItemDetailResult.markedAsFound;
    Navigator.of(context).pop(result);
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ItemFormScreen(item: _controller.item)),
    );
    if (saved == true && mounted && !_hasClosed) {
      _hasClosed = true;
      Navigator.of(context).pop(ItemDetailResult.updated);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir objeto?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _controller.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ItemActionsController>();
    final item = controller.item;
    final textTheme = Theme.of(context).textTheme;
    final createdAt = item.createdAt;
    return PopScope<Object?>(
      canPop: controller.canLeave,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const BackButtonIcon(),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: controller.isRunning
                ? null
                : () => Navigator.of(context).maybePop(),
          ),
          title: const Text('Detalhes do objeto'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(item.name, style: textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusBadge(status: item.status),
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      icon: Icons.place_outlined,
                      label: 'Local',
                      value: item.location,
                    ),
                    _InfoRow(
                      icon: Icons.notes,
                      label: 'Descrição',
                      value: item.description,
                    ),
                    if (createdAt != null)
                      _InfoRow(
                        icon: Icons.schedule,
                        label: 'Cadastrado em',
                        value: formatDateTime(createdAt),
                      ),
                    const SizedBox(height: 24),
                    _ActionArea(
                      controller: controller,
                      onEdit: _edit,
                      onDelete: _confirmDelete,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.controller,
    required this.onEdit,
    required this.onDelete,
  });

  final ItemActionsController controller;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDeleting = controller.action == ItemAction.delete;
    switch (controller.status) {
      case ActionStatus.idle:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.canMarkAsFound) ...[
              FilledButton.icon(
                onPressed: controller.markAsFound,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Marcar como encontrado'),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(foregroundColor: colors.error),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Excluir'),
            ),
          ],
        );
      case ActionStatus.running:
      case ActionStatus.success:
        return FilledButton.icon(
          onPressed: null,
          icon: const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: Text(isDeleting ? 'Excluindo...' : 'Salvando...'),
        );
      case ActionStatus.failure:
      case ActionStatus.uncertain:
        final isFailure = controller.status == ActionStatus.failure;
        final message = switch ((isFailure, isDeleting)) {
          (true, true) => 'Não foi possível excluir.',
          (true, false) => 'Não foi possível salvar.',
          (false, true) => 'Não foi possível confirmar a exclusão.',
          (false, false) => 'Não foi possível confirmar a alteração.',
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: colors.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colors.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$message Verifique sua conexão e tente novamente.',
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: controller.dismiss,
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: controller.retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ],
        );
    }
  }
}
