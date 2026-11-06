import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/lost_item_repository.dart';
import '../models/lost_item.dart';

enum LoadStatus { loading, success, failure }

class LostItemsController extends ChangeNotifier {
  LostItemsController(
    this._repository, {
    this.loadTimeout = const Duration(seconds: 15),
  });

  final LostItemRepository _repository;
  final Duration loadTimeout;

  List<LostItem> _items = const [];
  LoadStatus _status = LoadStatus.loading;
  bool _isRefreshing = false;
  int _requestCount = 0;
  bool _isDisposed = false;

  List<LostItem> get items => _items;
  LoadStatus get status => _status;
  bool get isLoading => _status == LoadStatus.loading || _isRefreshing;

  Future<void> loadItems() => _load(showLoading: true);

  Future<void> refreshItems() => _load(showLoading: false);

  Future<void> _load({required bool showLoading}) async {
    final request = ++_requestCount;
    if (showLoading) {
      _status = LoadStatus.loading;
    } else {
      _isRefreshing = true;
    }
    _notify();
    try {
      final items = await _repository.fetchItems().timeout(loadTimeout);
      if (request != _requestCount) {
        return;
      }
      _items = List.unmodifiable(items);
      _status = LoadStatus.success;
    } catch (_) {
      if (request != _requestCount) {
        return;
      }
      _status = LoadStatus.failure;
    } finally {
      if (request == _requestCount) {
        _isRefreshing = false;
        _notify();
      }
    }
  }

  void _notify() {
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
