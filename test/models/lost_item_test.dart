import 'package:achados_perdidos/models/lost_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ItemStatus.fromValue', () {
    test('parses lost', () {
      expect(ItemStatus.fromValue('lost'), ItemStatus.lost);
    });

    test('parses found', () {
      expect(ItemStatus.fromValue('found'), ItemStatus.found);
    });

    for (final value in ['', 'unknown', 'Lost', ' lost ']) {
      test('rejects invalid value "$value"', () {
        expect(() => ItemStatus.fromValue(value), throwsFormatException);
      });
    }
  });

  group('LostItemDraft', () {
    final draft = LostItemDraft(
      name: 'Caderno',
      description: 'Capa azul',
      location: 'Biblioteca',
      status: ItemStatus.lost,
    );

    test('compares equal fields and produces equal hash codes', () {
      final equivalent = LostItemDraft(
        name: 'Caderno',
        description: 'Capa azul',
        location: 'Biblioteca',
        status: ItemStatus.lost,
      );

      expect(identical(draft, equivalent), isFalse);
      expect(draft, equivalent);
      expect(equivalent, draft);
      expect(draft.hashCode, equivalent.hashCode);
      expect({draft, equivalent}, hasLength(1));
    });

    final differentDrafts = <String, LostItemDraft>{
      'name': const LostItemDraft(
        name: 'Livro',
        description: 'Capa azul',
        location: 'Biblioteca',
        status: ItemStatus.lost,
      ),
      'description': const LostItemDraft(
        name: 'Caderno',
        description: 'Capa verde',
        location: 'Biblioteca',
        status: ItemStatus.lost,
      ),
      'location': const LostItemDraft(
        name: 'Caderno',
        description: 'Capa azul',
        location: 'Bloco B',
        status: ItemStatus.lost,
      ),
      'status': const LostItemDraft(
        name: 'Caderno',
        description: 'Capa azul',
        location: 'Biblioteca',
        status: ItemStatus.found,
      ),
    };

    for (final entry in differentDrafts.entries) {
      test('compares unequal when ${entry.key} differs', () {
        expect(draft, isNot(entry.value));
      });
    }

    test('compares unequal to another type', () {
      expect(draft, isNot('Caderno'));
    });
  });

  group('LostItem.toDraft', () {
    for (final status in ItemStatus.values) {
      final item = LostItem(
        id: 'existing-item',
        name: 'Caderno',
        description: 'Capa azul',
        location: 'Biblioteca',
        status: status,
        createdAt: DateTime(2026, 11, 5, 14, 30),
      );

      test('copies every draft field for ${status.name}', () {
        expect(
          item.toDraft(),
          LostItemDraft(
            name: 'Caderno',
            description: 'Capa azul',
            location: 'Biblioteca',
            status: status,
          ),
        );
      });

      test('overrides ${status.name} without changing the original item', () {
        final replacement = status == ItemStatus.lost
            ? ItemStatus.found
            : ItemStatus.lost;

        expect(
          item.toDraft(status: replacement),
          LostItemDraft(
            name: 'Caderno',
            description: 'Capa azul',
            location: 'Biblioteca',
            status: replacement,
          ),
        );
        expect(item.status, status);
        expect(item.id, 'existing-item');
        expect(item.createdAt, DateTime(2026, 11, 5, 14, 30));
        expect(item.toDraft().status, status);
      });
    }
  });

  test('LostItemLimits matches the agreed field lengths', () {
    expect(LostItemLimits.nameMaxLength, 60);
    expect(LostItemLimits.descriptionMaxLength, 200);
    expect(LostItemLimits.locationMaxLength, 60);
  });
}
