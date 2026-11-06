import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lost_item.dart';

abstract interface class LostItemRepository {
  Future<List<LostItem>> fetchItems();

  String generateItemId();

  Future<void> createItem(String id, LostItemDraft draft);

  Future<void> updateItem(String id, LostItemDraft draft);

  Future<void> markItemAsFound(String id);

  Future<void> deleteItem(String id);
}

class ItemConflictException implements Exception {
  const ItemConflictException(this.id);

  final String id;

  @override
  String toString() => 'ItemConflictException: $id';
}

class ItemNotFoundException implements Exception {
  const ItemNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'ItemNotFoundException: $id';
}

class FirestoreLostItemRepository implements LostItemRepository {
  FirestoreLostItemRepository(this._firestore);

  static const String collectionPath = 'lost_items';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionPath);

  @override
  Future<List<LostItem>> fetchItems() async {
    final snapshot = await _collection
        .orderBy('createdAt', descending: true)
        .get(const GetOptions(source: Source.server));
    return snapshot.docs.map(_toItem).toList();
  }

  @override
  String generateItemId() => _collection.doc().id;

  @override
  Future<void> createItem(String id, LostItemDraft draft) {
    final reference = _collection.doc(id);
    return _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        transaction.set(reference, {
          ..._toData(draft),
          'createdAt': FieldValue.serverTimestamp(),
        });
        return;
      }
      if (_toDraft(snapshot.data()!) != draft) {
        throw ItemConflictException(id);
      }
    });
  }

  @override
  Future<void> updateItem(String id, LostItemDraft draft) {
    final reference = _collection.doc(id);
    return _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw ItemNotFoundException(id);
      }
      if (_toDraft(snapshot.data()!) == draft) {
        return;
      }
      transaction.update(reference, _toData(draft));
    });
  }

  @override
  Future<void> markItemAsFound(String id) {
    final reference = _collection.doc(id);
    return _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw ItemNotFoundException(id);
      }
      if (snapshot.data()!['status'] == ItemStatus.found.value) {
        return;
      }
      transaction.update(reference, {'status': ItemStatus.found.value});
    });
  }

  @override
  Future<void> deleteItem(String id) {
    final reference = _collection.doc(id);
    return _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      if (snapshot.exists) {
        transaction.delete(reference);
      }
    });
  }

  Map<String, Object> _toData(LostItemDraft draft) {
    return {
      'name': draft.name,
      'description': draft.description,
      'location': draft.location,
      'status': draft.status.value,
    };
  }

  LostItemDraft _toDraft(Map<String, dynamic> data) {
    return LostItemDraft(
      name: data['name'] as String,
      description: data['description'] as String,
      location: data['location'] as String,
      status: ItemStatus.fromValue(data['status'] as String),
    );
  }

  LostItem _toItem(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final draft = _toDraft(data);
    final createdAt = data['createdAt'];
    return LostItem(
      id: document.id,
      name: draft.name,
      description: draft.description,
      location: draft.location,
      status: draft.status,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}
