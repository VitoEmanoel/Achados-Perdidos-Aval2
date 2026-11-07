import 'dart:async';

import 'package:achados_perdidos/data/lost_item_repository.dart';
import 'package:achados_perdidos/models/lost_item.dart';
import 'package:achados_perdidos/state/item_actions_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_lost_item_repository.dart';

void main() {
  final item = LostItem(
    id: 'existing-item',
    name: 'Caderno',
    description: 'Capa azul',
    location: 'Biblioteca',
    status: ItemStatus.lost,
    createdAt: DateTime(2026, 11, 5, 14, 30),
  );

  late FakeLostItemRepository repository;
  late ItemActionsController controller;
  late bool disposed;

  setUp(() {
    repository = FakeLostItemRepository();
    controller = ItemActionsController(
      repository,
      item,
      actionTimeout: const Duration(milliseconds: 10),
    );
    disposed = false;
  });

  tearDown(() {
    if (!disposed) {
      controller.dispose();
    }
  });

  test('starts idle with no action and allows leaving', () {
    expectActionState(controller, ActionStatus.idle, null);
    expect(controller.item, same(item));
    expect(controller.canMarkAsFound, isTrue);
    expect(repository.markAsFoundCalls, isEmpty);
    expect(repository.updateCalls, isEmpty);
    expect(repository.deleteCalls, isEmpty);
  });

  test('ignores marking an item that is already found', () async {
    controller.dispose();
    controller = ItemActionsController(
      repository,
      const LostItem(
        id: 'found-item',
        name: 'Livro',
        description: 'Capa verde',
        location: 'Bloco B',
        status: ItemStatus.found,
        createdAt: null,
      ),
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.markAsFound();

    expect(controller.canMarkAsFound, isFalse);
    expectActionState(controller, ActionStatus.idle, null);
    expect(repository.markAsFoundCalls, isEmpty);
    expect(repository.updateCalls, isEmpty);
    expect(repository.deleteCalls, isEmpty);
    expect(notifications, 0);

    await controller.delete();
    expectActionState(controller, ActionStatus.success, ItemAction.delete);
    expect(repository.deleteCalls, ['found-item']);
  });

  test('retry and dismiss do nothing while idle', () async {
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.retry();
    controller.dismiss();

    expectActionState(controller, ActionStatus.idle, null);
    expect(notifications, 0);
    expect(repository.markAsFoundCalls, isEmpty);
    expect(repository.updateCalls, isEmpty);
    expect(repository.deleteCalls, isEmpty);
  });

  for (final action in ItemAction.values) {
    group(action.name, () {
      void expectCalls(int count) {
        expect(repository.generatedIds, isEmpty);
        expect(repository.createCalls, isEmpty);
        expect(repository.updateCalls, isEmpty);
        expect(
          repository.markAsFoundCalls,
          action == ItemAction.markAsFound
              ? List.filled(count, item.id)
              : isEmpty,
        );
        expect(
          repository.deleteCalls,
          action == ItemAction.delete ? List.filled(count, item.id) : isEmpty,
        );
      }

      void queueResponse(Completer<void> response) {
        if (action == ItemAction.markAsFound) {
          repository.markAsFoundCompleters.add(response);
        } else {
          repository.deleteCompleters.add(response);
        }
      }

      void setError(Object? error) {
        if (action == ItemAction.markAsFound) {
          repository.markAsFoundError = error;
        } else {
          repository.deleteError = error;
        }
      }

      test('sends the item id and succeeds with the selected action', () async {
        final response = Completer<void>();
        queueResponse(response);
        final states = <ActionStatus>[];
        controller.addListener(() => states.add(controller.status));

        final operation = performAction(controller, action);

        expectActionState(controller, ActionStatus.running, action);
        expectCalls(1);
        response.complete();
        await operation;

        expectActionState(controller, ActionStatus.success, action);
        expect(states, [ActionStatus.running, ActionStatus.success]);
        expect(item.status, ItemStatus.lost);
        expect(item.createdAt, DateTime(2026, 11, 5, 14, 30));
      });

      test('ignores all actions and dismiss while running', () async {
        final response = Completer<void>();
        queueResponse(response);
        final operation = performAction(controller, action);

        await controller.markAsFound();
        await controller.delete();
        await controller.retry();
        controller.dismiss();

        expectActionState(controller, ActionStatus.running, action);
        expectCalls(1);
        response.complete();
        await operation;
      });

      test('ignores new actions and retry after success', () async {
        await performAction(controller, action);

        await controller.markAsFound();
        await controller.delete();
        await controller.retry();
        controller.dismiss();

        expectActionState(controller, ActionStatus.success, action);
        expectCalls(1);
      });

      for (final timesOut in [false, true]) {
        final outcome = timesOut ? 'timeout' : 'error';

        test('retries the same action after $outcome', () async {
          final response = Completer<void>();
          if (timesOut) {
            queueResponse(response);
          } else {
            setError(ItemNotFoundException(item.id));
          }

          await performAction(controller, action);

          expectActionState(
            controller,
            timesOut ? ActionStatus.uncertain : ActionStatus.failure,
            action,
          );
          expectCalls(1);
          await controller.markAsFound();
          await controller.delete();
          expectCalls(1);
          setError(null);

          await controller.retry();

          expectActionState(controller, ActionStatus.success, action);
          expectCalls(2);
          if (timesOut) {
            response.completeError(StateError('late action failure'));
            await Future<void>.delayed(Duration.zero);
            expectActionState(controller, ActionStatus.success, action);
          }
        });

        test(
          'dismiss clears the action after $outcome and allows new work',
          () async {
            final response = Completer<void>();
            if (timesOut) {
              queueResponse(response);
            } else {
              setError(StateError('action failed'));
            }
            await performAction(controller, action);
            final states = <ActionStatus>[];
            controller.addListener(() => states.add(controller.status));

            controller.dismiss();

            expectActionState(controller, ActionStatus.idle, null);
            expect(states, [ActionStatus.idle]);
            await controller.retry();
            expectCalls(1);
            if (timesOut) {
              response.complete();
              await Future<void>.delayed(Duration.zero);
              expectActionState(controller, ActionStatus.idle, null);
            }
            setError(null);
            final nextAction = action == ItemAction.delete
                ? ItemAction.markAsFound
                : ItemAction.delete;
            await performAction(controller, nextAction);
            expectActionState(controller, ActionStatus.success, nextAction);
            expect(repository.deleteCalls, [item.id]);
            expect(repository.markAsFoundCalls, [item.id]);
            expect(repository.updateCalls, isEmpty);
          },
        );
      }

      for (final lateError in [false, true]) {
        test(
          'keeps uncertainty after late ${lateError ? 'failure' : 'success'}',
          () async {
            final response = Completer<void>();
            queueResponse(response);
            final states = <ActionStatus>[];
            controller.addListener(() => states.add(controller.status));

            await performAction(controller, action);

            expectActionState(controller, ActionStatus.uncertain, action);
            if (lateError) {
              response.completeError(StateError('late action failure'));
            } else {
              response.complete();
            }
            await Future<void>.delayed(Duration.zero);
            expectActionState(controller, ActionStatus.uncertain, action);
            expect(states, [ActionStatus.running, ActionStatus.uncertain]);
          },
        );
      }

      for (final outcome in ['success', 'error', 'timeout']) {
        test('does not notify or throw after dispose on $outcome', () async {
          final response = Completer<void>();
          queueResponse(response);
          var notifications = 0;
          controller.addListener(() => notifications++);
          final operation = performAction(controller, action);
          expect(notifications, 1);

          controller.dispose();
          disposed = true;
          if (outcome == 'success') {
            response.complete();
          } else if (outcome == 'error') {
            response.completeError(StateError('action failed'));
          }

          await expectLater(operation, completes);
          expect(notifications, 1);
          if (outcome == 'timeout') {
            response.completeError(StateError('late action failure'));
            await Future<void>.delayed(Duration.zero);
            expect(notifications, 1);
          }
        });
      }
    });
  }
}

Future<void> performAction(
  ItemActionsController controller,
  ItemAction action,
) {
  return switch (action) {
    ItemAction.markAsFound => controller.markAsFound(),
    ItemAction.delete => controller.delete(),
  };
}

void expectActionState(
  ItemActionsController controller,
  ActionStatus status,
  ItemAction? action,
) {
  expect(controller.status, status);
  expect(controller.action, action);
  expect(controller.isIdle, status == ActionStatus.idle);
  expect(controller.isRunning, status == ActionStatus.running);
  expect(controller.canLeave, status != ActionStatus.running);
  expect(
    controller.hasUnresolvedAction,
    status == ActionStatus.failure || status == ActionStatus.uncertain,
  );
}
