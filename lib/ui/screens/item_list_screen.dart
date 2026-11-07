import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/lost_item.dart';
import '../../state/lost_items_controller.dart';
import '../widgets/lost_item_card.dart';
import '../widgets/scrollable_message.dart';
import 'item_detail_screen.dart';
import 'item_form_screen.dart';

class ItemListScreen extends StatelessWidget {
  const ItemListScreen({super.key});

  Future<void> _openForm(BuildContext context) async {
    final controller = context.read<LostItemsController>();
    final messenger = ScaffoldMessenger.of(context);
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const ItemFormScreen()));
    if (saved != true) {
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('Objeto cadastrado.')));
    await controller.loadItems();
  }

  Future<void> _openDetail(BuildContext context, LostItem item) async {
    final controller = context.read<LostItemsController>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await Navigator.of(context).push<ItemDetailResult>(
      MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
    );
    if (result == null) {
      return;
    }
    final message = switch (result) {
      ItemDetailResult.updated => 'Objeto atualizado.',
      ItemDetailResult.markedAsFound => 'Objeto marcado como encontrado.',
      ItemDetailResult.deleted => 'Objeto excluído.',
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
    await controller.loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LostItemsController>();
    final showTopProgress =
        controller.status == LoadStatus.loading && controller.items.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achados e Perdidos'),
        bottom: showTopProgress
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Cadastrar objeto'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refreshItems,
          child: _ItemListBody(
            controller: controller,
            onOpenItem: (item) => _openDetail(context, item),
          ),
        ),
      ),
    );
  }
}

class _ItemListBody extends StatelessWidget {
  const _ItemListBody({required this.controller, required this.onOpenItem});

  final LostItemsController controller;
  final ValueChanged<LostItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = controller.items;
    if (controller.status == LoadStatus.failure) {
      return ScrollableMessage(
        icon: Icon(Icons.cloud_off, size: 48, color: colors.error),
        message:
            'Não foi possível carregar os objetos. '
            'Verifique sua conexão e tente novamente.',
        action: FilledButton.icon(
          onPressed: controller.loadItems,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      );
    }
    if (controller.status == LoadStatus.loading && items.isEmpty) {
      return const ScrollableMessage(
        icon: CircularProgressIndicator(),
        message: 'Carregando objetos...',
      );
    }
    if (items.isEmpty) {
      return ScrollableMessage(
        icon: Icon(Icons.inventory_2_outlined, size: 48, color: colors.primary),
        message:
            'Nenhum objeto cadastrado ainda.\n'
            'Toque em "Cadastrar objeto" para adicionar o primeiro.',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: LostItemCard(
              item: items[index],
              onTap: () => onOpenItem(items[index]),
            ),
          ),
        );
      },
    );
  }
}
