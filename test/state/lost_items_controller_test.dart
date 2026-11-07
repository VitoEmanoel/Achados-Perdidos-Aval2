import 'dart:async';

import 'package:achados_perdidos/models/lost_item.dart';
import 'package:achados_perdidos/state/lost_items_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_lost_item_repository.dart';

void main() {
  const olderItem = LostItem(
    id: 'older',
    name: 'Caderno',
    description: 'Capa azul',
    location: 'Biblioteca',
    status: ItemStatus.lost,
    createdAt: null,
  );
  const newerItem = LostItem(
    id: 'newer',
    name: 'Livro',
    description: 'Capa verde',
    location: 'Bloco B',
    status: ItemStatus.found,
    createdAt: null,
  );

  late FakeLostItemRepository repository;
  late LostItemsController controller;

  setUp(() {
    repository = FakeLostItemRepository();
    controller = LostItemsController(repository);
  });

  tearDown(() {
    controller.dispose();
  });

  test('starts loading without fetching automatically', () {
    expect(controller.status, LoadStatus.loading);
    expect(controller.isLoading, isTrue);
    expect(controller.items, isEmpty);
    expect(repository.fetchCallCount, 0);
  });

  test('loads items in repository order into an immutable list', () async {
    repository.items = [newerItem, olderItem];

    await controller.loadItems();

    expect(repository.fetchCallCount, 1);
    expect(controller.status, LoadStatus.success);
    expect(controller.isLoading, isFalse);
    expect(controller.items, [newerItem, olderItem]);
    expect(() => controller.items.add(olderItem), throwsUnsupportedError);
    repository.items.clear();
    expect(controller.items, hasLength(2));
  });

  test('loads an empty list successfully', () async {
    await controller.loadItems();

    expect(controller.status, LoadStatus.success);
    expect(controller.items, isEmpty);
    expect(controller.isLoading, isFalse);
  });

  test('reports failure when fetching throws', () async {
    repository.fetchError = StateError('fetch failed');

    await controller.loadItems();

    expect(controller.status, LoadStatus.failure);
    expect(controller.isLoading, isFalse);
    expect(controller.items, isEmpty);
  });

  test(
    'reports failure after the load timeout and ignores late data',
    () async {
      controller.dispose();
      controller = LostItemsController(
        repository,
        loadTimeout: const Duration(milliseconds: 10),
      );
      final response = Completer<List<LostItem>>();
      repository.fetchCompleters.add(response);

      await controller.loadItems();

      expect(controller.status, LoadStatus.failure);
      expect(controller.isLoading, isFalse);
      response.complete([olderItem]);
      await response.future;
      expect(controller.status, LoadStatus.failure);
      expect(controller.items, isEmpty);
    },
  );

  test('refresh keeps success and existing items while loading', () async {
    repository.items = [olderItem];
    await controller.loadItems();
    final response = Completer<List<LostItem>>();
    repository.fetchCompleters.add(response);

    final refresh = controller.refreshItems();

    expect(controller.status, LoadStatus.success);
    expect(controller.isLoading, isTrue);
    expect(controller.items, [olderItem]);
    response.complete([newerItem]);
    await refresh;
    expect(controller.status, LoadStatus.success);
    expect(controller.isLoading, isFalse);
    expect(controller.items, [newerItem]);
  });

  test('refresh failure keeps items and clears the loading flag', () async {
    repository.items = [olderItem];
    await controller.loadItems();
    repository.fetchError = StateError('refresh failed');

    await controller.refreshItems();

    expect(controller.status, LoadStatus.failure);
    expect(controller.items, [olderItem]);
    expect(controller.isLoading, isFalse);
  });

  for (final staleFails in [false, true]) {
    test(
      'ignores a stale ${staleFails ? 'error' : 'success'} response',
      () async {
        final olderResponse = Completer<List<LostItem>>();
        final newerResponse = Completer<List<LostItem>>();
        repository.fetchCompleters.addAll([olderResponse, newerResponse]);
        final olderLoad = controller.loadItems();
        final newerLoad = controller.loadItems();

        newerResponse.complete([newerItem]);
        await newerLoad;
        var notifications = 0;
        controller.addListener(() => notifications++);
        if (staleFails) {
          olderResponse.completeError(StateError('stale failure'));
        } else {
          olderResponse.complete([olderItem]);
        }
        await olderLoad;

        expect(repository.fetchCallCount, 2);
        expect(controller.status, LoadStatus.success);
        expect(controller.items, [newerItem]);
        expect(controller.isLoading, isFalse);
        expect(notifications, 0);
      },
    );
  }

  test('stale completion does not stop a newer pending load', () async {
    final olderResponse = Completer<List<LostItem>>();
    final newerResponse = Completer<List<LostItem>>();
    repository.fetchCompleters.addAll([olderResponse, newerResponse]);
    final olderLoad = controller.loadItems();
    final newerLoad = controller.loadItems();

    olderResponse.complete([olderItem]);
    await olderLoad;
    expect(controller.status, LoadStatus.loading);
    expect(controller.isLoading, isTrue);
    expect(controller.items, isEmpty);

    newerResponse.complete([newerItem]);
    await newerLoad;
    expect(controller.items, [newerItem]);
    expect(controller.isLoading, isFalse);
  });

  test('notifies listeners at the start and end of each load', () async {
    final states = <({LoadStatus status, bool isLoading})>[];
    controller.addListener(() {
      states.add((status: controller.status, isLoading: controller.isLoading));
    });

    await controller.loadItems();
    await controller.refreshItems();

    expect(states, [
      (status: LoadStatus.loading, isLoading: true),
      (status: LoadStatus.success, isLoading: false),
      (status: LoadStatus.success, isLoading: true),
      (status: LoadStatus.success, isLoading: false),
    ]);
  });
}
