import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/lost_item_repository.dart';
import '../models/lost_item.dart';

enum SubmissionStatus { editing, submitting, failure, uncertain, success }

class PendingSubmission {
  const PendingSubmission({required this.id, required this.draft});

  final String id;
  final LostItemDraft draft;
}

class ItemFormController extends ChangeNotifier {
  ItemFormController(
    this._repository, {
    this.editingItem,
    this.submitTimeout = const Duration(seconds: 15),
  });

  final LostItemRepository _repository;
  final LostItem? editingItem;
  final Duration submitTimeout;

  SubmissionStatus _status = SubmissionStatus.editing;
  PendingSubmission? _pending;
  bool _isDisposed = false;

  SubmissionStatus get status => _status;
  PendingSubmission? get pending => _pending;
  bool get isEditing => editingItem != null;
  bool get isEditable => _status == SubmissionStatus.editing;
  bool get isSubmitting => _status == SubmissionStatus.submitting;
  bool get hasUnresolvedSubmission =>
      _status == SubmissionStatus.failure ||
      _status == SubmissionStatus.uncertain;
  bool get canLeave =>
      _status == SubmissionStatus.editing ||
      _status == SubmissionStatus.success;

  Future<void> submit(LostItemDraft draft) async {
    if (!isEditable) {
      return;
    }
    _pending = PendingSubmission(
      id: editingItem?.id ?? _repository.generateItemId(),
      draft: draft,
    );
    await _send();
  }

  Future<void> retry() async {
    if (!hasUnresolvedSubmission || _pending == null) {
      return;
    }
    await _send();
  }

  void discard() {
    if (!hasUnresolvedSubmission) {
      return;
    }
    _pending = null;
    _setStatus(SubmissionStatus.editing);
  }

  Future<void> _send() async {
    final pending = _pending!;
    _setStatus(SubmissionStatus.submitting);
    try {
      final operation = isEditing
          ? _repository.updateItem(pending.id, pending.draft)
          : _repository.createItem(pending.id, pending.draft);
      await operation.timeout(submitTimeout);
      _setStatus(SubmissionStatus.success);
    } on TimeoutException {
      _setStatus(SubmissionStatus.uncertain);
    } catch (_) {
      _setStatus(SubmissionStatus.failure);
    }
  }

  void _setStatus(SubmissionStatus status) {
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
