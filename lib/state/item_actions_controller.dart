import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/lost_item_repository.dart';
import '../models/lost_item.dart';

enum ItemAction { markAsFound, delete }

enum ActionStatus { idle, running, failure, uncertain, success }

class ItemActionsController extends ChangeNotifier {
  ItemActionsController(
    this._repository,
    this.item, {
    this.actionTimeout = const Duration(seconds: 15),
  });

  final LostItemRepository _repository;
  final LostItem item;
  final Duration actionTimeout;

  ActionStatus _status = ActionStatus.idle;
  ItemAction? _action;
  bool _isDisposed = false;

  ActionStatus get status => _status;
  ItemAction? get action => _action;
  bool get isIdle => _status == ActionStatus.idle;
  bool get isRunning => _status == ActionStatus.running;
  bool get hasUnresolvedAction =>
      _status == ActionStatus.failure || _status == ActionStatus.uncertain;
  bool get canLeave => _status != ActionStatus.running;
  bool get canMarkAsFound => item.status == ItemStatus.lost;

  Future<void> markAsFound() async {
    if (!canMarkAsFound) {
      return;
    }
    await _start(ItemAction.markAsFound);
  }

  Future<void> delete() => _start(ItemAction.delete);

  Future<void> retry() async {
    if (!hasUnresolvedAction || _action == null) {
      return;
    }
    await _run();
  }

  void dismiss() {
    if (!hasUnresolvedAction) {
      return;
    }
    _action = null;
    _setStatus(ActionStatus.idle);
  }

  Future<void> _start(ItemAction action) async {
    if (!isIdle) {
      return;
    }
    _action = action;
    await _run();
  }

  Future<void> _run() async {
    _setStatus(ActionStatus.running);
    try {
      final operation = switch (_action!) {
        ItemAction.markAsFound => _repository.markItemAsFound(item.id),
        ItemAction.delete => _repository.deleteItem(item.id),
      };
      await operation.timeout(actionTimeout);
      _setStatus(ActionStatus.success);
    } on TimeoutException {
      _setStatus(ActionStatus.uncertain);
    } catch (_) {
      _setStatus(ActionStatus.failure);
    }
  }

  void _setStatus(ActionStatus status) {
    _status = status;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
