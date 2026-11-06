import 'dart:async';

import 'package:achados_perdidos/data/lost_item_repository.dart';
import 'package:achados_perdidos/models/lost_item.dart';

class FakeLostItemRepository implements LostItemRepository {
  FakeLostItemRepository({List<LostItem> items = const []})
    : items = List.of(items);

  List<LostItem> items;
  Object? fetchError;
  Object? createError;
  int fetchCallCount = 0;
  final generatedIds = <String>[];
  final createCalls = <({String id, LostItemDraft draft})>[];
  final fetchCompleters = <Completer<List<LostItem>>>[];
  final createCompleters = <Completer<void>>[];

  @override
  Future<List<LostItem>> fetchItems() async {
    fetchCallCount++;
    if (fetchCompleters.isNotEmpty) {
      return fetchCompleters.removeAt(0).future;
    }
    final error = fetchError;
    if (error != null) {
      throw error;
    }
    return List.of(items);
  }

  @override
  String generateItemId() {
    final id = 'item-${generatedIds.length + 1}';
    generatedIds.add(id);
    return id;
  }

  @override
  Future<void> createItem(String id, LostItemDraft draft) async {
    createCalls.add((id: id, draft: draft));
    if (createCompleters.isNotEmpty) {
      return createCompleters.removeAt(0).future;
    }
    final error = createError;
    if (error != null) {
      throw error;
    }
  }

  Object? updateError;
  Object? markAsFoundError;
  Object? deleteError;
  final updateCalls = <({String id, LostItemDraft draft})>[];
  final markAsFoundCalls = <String>[];
  final deleteCalls = <String>[];
  final updateCompleters = <Completer<void>>[];
  final markAsFoundCompleters = <Completer<void>>[];
  final deleteCompleters = <Completer<void>>[];

  @override
  Future<void> updateItem(String id, LostItemDraft draft) async {
    updateCalls.add((id: id, draft: draft));
    if (updateCompleters.isNotEmpty) {
      return updateCompleters.removeAt(0).future;
    }
    final error = updateError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> markItemAsFound(String id) async {
    markAsFoundCalls.add(id);
    if (markAsFoundCompleters.isNotEmpty) {
      await markAsFoundCompleters.removeAt(0).future;
    } else {
      final error = markAsFoundError;
      if (error != null) {
        throw error;
      }
    }
    items = [
      for (final item in items)
        if (item.id == id)
          LostItem(
            id: item.id,
            name: item.name,
            description: item.description,
            location: item.location,
            status: ItemStatus.found,
            createdAt: item.createdAt,
          )
        else
          item,
    ];
  }

  @override
  Future<void> deleteItem(String id) async {
    deleteCalls.add(id);
    if (deleteCompleters.isNotEmpty) {
      return deleteCompleters.removeAt(0).future;
    }
    final error = deleteError;
    if (error != null) {
      throw error;
    }
  }
}
