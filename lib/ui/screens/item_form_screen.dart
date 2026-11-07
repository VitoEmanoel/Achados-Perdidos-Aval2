import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/lost_item_repository.dart';
import '../../models/lost_item.dart';
import '../../state/item_form_controller.dart';
import '../widgets/item_status_style.dart';

class ItemFormScreen extends StatelessWidget {
  const ItemFormScreen({super.key, this.item});

  final LostItem? item;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ItemFormController(
        context.read<LostItemRepository>(),
        editingItem: item,
      ),
      child: const _ItemFormView(),
    );
  }
}

class _ItemFormView extends StatefulWidget {
  const _ItemFormView();

  @override
  State<_ItemFormView> createState() => _ItemFormViewState();
}

class _ItemFormViewState extends State<_ItemFormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _statusFieldKey = GlobalKey<FormFieldState<ItemStatus>>();
  late final ItemFormController _controller;
  bool _hasClosed = false;

  @override
  void initState() {
    super.initState();
    _controller = context.read<ItemFormController>();
    _controller.addListener(_closeOnSuccess);
    final item = _controller.editingItem;
    if (item != null) {
      _nameController.text = item.name;
      _descriptionController.text = item.description;
      _locationController.text = item.location;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_closeOnSuccess);
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _closeOnSuccess() {
    if (_controller.status == SubmissionStatus.success && !_hasClosed) {
      _hasClosed = true;
      Navigator.of(context).pop(true);
    }
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _controller.submit(
      LostItemDraft(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        status: _statusFieldKey.currentState!.value!,
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _controller.isEditing
              ? 'Descartar alteração?'
              : 'Descartar cadastro?',
        ),
        content: Text(
          _controller.isEditing
              ? 'A alteração pode já ter sido salva. '
                    'Atualize a lista para conferir.'
              : 'O cadastro pode já ter sido salvo. '
                    'Atualize a lista para conferir antes de cadastrar de novo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar aqui'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _discard() async {
    if (await _confirmDiscard() && mounted) {
      _controller.discard();
    }
  }

  Future<void> _handleBlockedPop(bool didPop, Object? result) async {
    if (didPop || !_controller.hasUnresolvedSubmission) {
      return;
    }
    if (await _confirmDiscard() && mounted) {
      _controller.discard();
      Navigator.of(context).pop(false);
    }
  }

  String? _validateText(String? value, String field, int maxLength) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Informe $field.';
    }
    if (text.length > maxLength) {
      return 'Use no máximo $maxLength caracteres.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ItemFormController>();
    final isEditable = controller.isEditable;
    return PopScope<Object?>(
      canPop: controller.canLeave,
      onPopInvokedWithResult: _handleBlockedPop,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const BackButtonIcon(),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: controller.isSubmitting
                ? null
                : () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            controller.isEditing ? 'Editar objeto' : 'Cadastrar objeto',
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        enabled: isEditable,
                        maxLength: LostItemLimits.nameMaxLength,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Nome do objeto',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => _validateText(
                          value,
                          'o nome do objeto',
                          LostItemLimits.nameMaxLength,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        enabled: isEditable,
                        maxLength: LostItemLimits.descriptionMaxLength,
                        minLines: 3,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => _validateText(
                          value,
                          'a descrição',
                          LostItemLimits.descriptionMaxLength,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _locationController,
                        enabled: isEditable,
                        maxLength: LostItemLimits.locationMaxLength,
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Local',
                          hintText: 'Ex.: Biblioteca, Bloco B',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => _validateText(
                          value,
                          'o local',
                          LostItemLimits.locationMaxLength,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _StatusField(
                        fieldKey: _statusFieldKey,
                        enabled: isEditable,
                        initialValue: controller.editingItem?.status,
                      ),
                      const SizedBox(height: 24),
                      _SubmissionArea(
                        controller: controller,
                        onSubmit: _submit,
                        onDiscard: _discard,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusField extends StatelessWidget {
  const _StatusField({
    required this.fieldKey,
    required this.enabled,
    this.initialValue,
  });

  final GlobalKey<FormFieldState<ItemStatus>> fieldKey;
  final bool enabled;
  final ItemStatus? initialValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FormField<ItemStatus>(
      key: fieldKey,
      initialValue: initialValue,
      validator: (value) => value == null ? 'Selecione a situação.' : null,
      builder: (field) {
        final selected = field.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Situação', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            IgnorePointer(
              ignoring: !enabled,
              child: ExcludeFocus(
                excluding: !enabled,
                child: SegmentedButton<ItemStatus>(
                  segments: [
                    for (final status in ItemStatus.values)
                      ButtonSegment(
                        value: status,
                        icon: Icon(status.icon),
                        label: Text(status.label),
                      ),
                  ],
                  selected: selected == null ? const {} : {selected},
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    if (!enabled) {
                      return;
                    }
                    field.didChange(selection.isEmpty ? null : selection.first);
                  },
                ),
              ),
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 12),
                child: Text(
                  field.errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SubmissionArea extends StatelessWidget {
  const _SubmissionArea({
    required this.controller,
    required this.onSubmit,
    required this.onDiscard,
  });

  final ItemFormController controller;
  final VoidCallback onSubmit;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    switch (controller.status) {
      case SubmissionStatus.editing:
        return FilledButton.icon(
          onPressed: onSubmit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Salvar'),
        );
      case SubmissionStatus.submitting:
      case SubmissionStatus.success:
        return FilledButton.icon(
          onPressed: null,
          icon: const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: const Text('Salvando...'),
        );
      case SubmissionStatus.failure:
      case SubmissionStatus.uncertain:
        final message = controller.status == SubmissionStatus.failure
            ? 'Não foi possível salvar. '
                  'Verifique sua conexão e tente novamente.'
            : controller.isEditing
            ? 'Não foi possível confirmar a alteração. '
                  'Verifique sua conexão e tente novamente.'
            : 'Não foi possível confirmar o cadastro. '
                  'Verifique sua conexão e tente novamente.';
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
                        message,
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
                  onPressed: onDiscard,
                  child: const Text('Descartar'),
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
