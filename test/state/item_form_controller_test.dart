import 'dart:async';

import 'package:achados_perdidos/data/lost_item_repository.dart';
import 'package:achados_perdidos/models/lost_item.dart';
import 'package:achados_perdidos/state/item_form_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_lost_item_repository.dart';

void main() {
  const draft = LostItemDraft(
    name: 'Caderno',
    description: 'Capa azul',
    location: 'Biblioteca',
    status: ItemStatus.lost,
  );
  const otherDraft = LostItemDraft(
    name: 'Livro',
    description: 'Capa verde',
    location: 'Bloco B',
    status: ItemStatus.found,
  );

  late FakeLostItemRepository repository;
  late ItemFormController controller;
  late bool disposed;

  setUp(() {
    repository = FakeLostItemRepository();
    controller = ItemFormController(
      repository,
      submitTimeout: const Duration(milliseconds: 10),
    );
    disposed = false;
  });

  tearDown(() {
    if (!disposed) {
      controller.dispose();
    }
  });

  group('editing an existing item', () {
    final item = LostItem(
      id: 'existing-item',
      name: 'Caderno',
      description: 'Capa azul',
      location: 'Biblioteca',
      status: ItemStatus.lost,
      createdAt: DateTime(2026, 11, 5, 14, 30),
    );

    setUp(() {
      controller.dispose();
      controller = ItemFormController(
        repository,
        editingItem: item,
        submitTimeout: const Duration(milliseconds: 10),
      );
    });

    test(
      'exposes the editing item and updates its id without creating',
      () async {
        final response = Completer<void>();
        repository.updateCompleters.add(response);

        expect(controller.isEditing, isTrue);
        expect(controller.editingItem, same(item));
        expectState(controller, SubmissionStatus.editing);
        final submission = controller.submit(otherDraft);

        expectState(controller, SubmissionStatus.submitting);
        expect(controller.pending!.id, item.id);
        expect(controller.pending!.draft, same(otherDraft));
        expect(repository.updateCalls, [(id: item.id, draft: otherDraft)]);
        expect(repository.generatedIds, isEmpty);
        expect(repository.createCalls, isEmpty);

        response.complete();
        await submission;

        expectState(controller, SubmissionStatus.success);
        expect(item.createdAt, DateTime(2026, 11, 5, 14, 30));
      },
    );

    test('reports failure when the edited item no longer exists', () async {
      repository.updateError = ItemNotFoundException(item.id);

      await controller.submit(otherDraft);

      expectState(controller, SubmissionStatus.failure);
      expect(controller.pending!.id, item.id);
      expect(controller.pending!.draft, same(otherDraft));
      expect(repository.updateCalls, [(id: item.id, draft: otherDraft)]);
      expect(repository.createCalls, isEmpty);
      expect(repository.generatedIds, isEmpty);
    });

    test(
      'reports uncertainty after update timeout and ignores late success',
      () async {
        final response = Completer<void>();
        repository.updateCompleters.add(response);

        await controller.submit(otherDraft);

        expectState(controller, SubmissionStatus.uncertain);
        expect(controller.pending!.id, item.id);
        expect(controller.pending!.draft, same(otherDraft));
        response.complete();
        await response.future;
        expectState(controller, SubmissionStatus.uncertain);
        expect(repository.createCalls, isEmpty);
        expect(repository.generatedIds, isEmpty);
      },
    );

    for (final timesOut in [false, true]) {
      test(
        'retry preserves the update id and draft after ${timesOut ? 'timeout' : 'error'}',
        () async {
          final response = Completer<void>();
          if (timesOut) {
            repository.updateCompleters.add(response);
          } else {
            repository.updateError = StateError('update failed');
          }
          await controller.submit(otherDraft);
          expectState(
            controller,
            timesOut ? SubmissionStatus.uncertain : SubmissionStatus.failure,
          );
          final pending = controller.pending;

          await controller.submit(draft);
          repository.updateError = null;
          await controller.retry();

          expectState(controller, SubmissionStatus.success);
          expect(controller.pending, same(pending));
          expect(repository.updateCalls, [
            (id: item.id, draft: otherDraft),
            (id: item.id, draft: otherDraft),
          ]);
          expect(repository.updateCalls.last.draft, same(otherDraft));
          expect(repository.generatedIds, isEmpty);
          expect(repository.createCalls, isEmpty);
          if (timesOut) {
            response.completeError(StateError('late update failure'));
            await Future<void>.delayed(Duration.zero);
            expectState(controller, SubmissionStatus.success);
          }
        },
      );
    }

    test('ignores repeated updates while submitting', () async {
      final response = Completer<void>();
      repository.updateCompleters.add(response);
      final submission = controller.submit(otherDraft);

      await controller.submit(draft);
      await controller.retry();
      controller.discard();

      expectState(controller, SubmissionStatus.submitting);
      expect(repository.updateCalls, [(id: item.id, draft: otherDraft)]);
      expect(repository.createCalls, isEmpty);
      expect(repository.generatedIds, isEmpty);
      response.complete();
      await submission;
    });
  });

  test('starts editing without a pending submission', () {
    expectState(controller, SubmissionStatus.editing);
    expect(controller.pending, isNull);
    expect(repository.generatedIds, isEmpty);
    expect(repository.createCalls, isEmpty);
  });

  test('generates one id and sends the submitted draft once', () async {
    final response = Completer<void>();
    repository.createCompleters.add(response);

    final submission = controller.submit(draft);

    expectState(controller, SubmissionStatus.submitting);
    expect(repository.generatedIds, ['item-1']);
    expect(repository.createCalls, [(id: 'item-1', draft: draft)]);
    expect(controller.pending!.id, 'item-1');
    expect(controller.pending!.draft, same(draft));

    response.complete();
    await submission;
    expectState(controller, SubmissionStatus.success);
  });

  test('reports failure and preserves the pending operation', () async {
    repository.createError = StateError('create failed');

    await controller.submit(draft);

    expectState(controller, SubmissionStatus.failure);
    expect(controller.pending!.id, 'item-1');
    expect(controller.pending!.draft, same(draft));
  });

  test('reports uncertainty after timeout and ignores late success', () async {
    final response = Completer<void>();
    repository.createCompleters.add(response);

    await controller.submit(draft);

    expectState(controller, SubmissionStatus.uncertain);
    expect(controller.pending!.id, 'item-1');
    response.complete();
    await response.future;
    expectState(controller, SubmissionStatus.uncertain);
  });

  for (final timesOut in [false, true]) {
    test(
      'retry reuses id and draft after ${timesOut ? 'timeout' : 'error'}',
      () async {
        final response = Completer<void>();
        if (timesOut) {
          repository.createCompleters.add(response);
        } else {
          repository.createError = StateError('create failed');
        }
        await controller.submit(draft);
        final pending = controller.pending;
        repository.createError = null;

        await controller.retry();

        expectState(controller, SubmissionStatus.success);
        expect(controller.pending, same(pending));
        expect(repository.generatedIds, ['item-1']);
        expect(repository.createCalls, [
          (id: 'item-1', draft: draft),
          (id: 'item-1', draft: draft),
        ]);
        expect(repository.createCalls.last.draft, same(draft));
        if (timesOut) {
          response.complete();
          await response.future;
        }
      },
    );
  }

  test('ignores repeated submit and retry while submitting', () async {
    final response = Completer<void>();
    repository.createCompleters.add(response);
    final submission = controller.submit(draft);

    await controller.submit(otherDraft);
    await controller.retry();
    controller.discard();

    expectState(controller, SubmissionStatus.submitting);
    expect(repository.generatedIds, ['item-1']);
    expect(repository.createCalls, [(id: 'item-1', draft: draft)]);
    response.complete();
    await submission;
  });

  for (final timesOut in [false, true]) {
    test(
      'discard clears pending after ${timesOut ? 'timeout' : 'error'}',
      () async {
        final response = Completer<void>();
        if (timesOut) {
          repository.createCompleters.add(response);
        } else {
          repository.createError = StateError('create failed');
        }
        await controller.submit(draft);

        controller.discard();

        expectState(controller, SubmissionStatus.editing);
        expect(controller.pending, isNull);
        repository.createError = null;
        await controller.submit(otherDraft);
        expect(repository.generatedIds, ['item-1', 'item-2']);
        expect(repository.createCalls.last, (id: 'item-2', draft: otherDraft));
        expectState(controller, SubmissionStatus.success);
        if (timesOut) {
          response.complete();
          await response.future;
          expectState(controller, SubmissionStatus.success);
          expect(controller.pending!.id, 'item-2');
        }
      },
    );
  }

  test(
    'rejects a new draft until the unresolved operation is discarded',
    () async {
      repository.createError = StateError('create failed');
      await controller.submit(draft);

      await controller.submit(otherDraft);

      expect(repository.generatedIds, ['item-1']);
      expect(repository.createCalls, [(id: 'item-1', draft: draft)]);
      expect(controller.pending!.draft, same(draft));
    },
  );

  test(
    'retry without pending does nothing and success rejects new work',
    () async {
      await controller.retry();
      controller.discard();
      expectState(controller, SubmissionStatus.editing);
      expect(repository.createCalls, isEmpty);

      await controller.submit(draft);
      await controller.submit(otherDraft);
      await controller.retry();
      controller.discard();
      expectState(controller, SubmissionStatus.success);
      expect(repository.createCalls, hasLength(1));
    },
  );

  test('notifies listeners about submission and discard transitions', () async {
    final states = <SubmissionStatus>[];
    controller.addListener(() => states.add(controller.status));
    repository.createError = StateError('create failed');

    await controller.submit(draft);
    controller.discard();
    repository.createError = null;
    await controller.submit(otherDraft);

    expect(states, [
      SubmissionStatus.submitting,
      SubmissionStatus.failure,
      SubmissionStatus.editing,
      SubmissionStatus.submitting,
      SubmissionStatus.success,
    ]);
  });

  for (final outcome in ['success', 'error', 'timeout']) {
    test('does not notify or throw after dispose on $outcome', () async {
      final response = Completer<void>();
      repository.createCompleters.add(response);
      var notifications = 0;
      controller.addListener(() => notifications++);
      final submission = controller.submit(draft);
      expect(notifications, 1);

      controller.dispose();
      disposed = true;
      if (outcome == 'success') {
        response.complete();
      } else if (outcome == 'error') {
        response.completeError(StateError('create failed'));
      }

      await expectLater(submission, completes);
      expect(notifications, 1);
      if (outcome == 'timeout') {
        response.complete();
        await response.future;
        expect(notifications, 1);
      }
    });
  }
}

void expectState(ItemFormController controller, SubmissionStatus status) {
  expect(controller.status, status);
  expect(
    controller.canLeave,
    status == SubmissionStatus.editing || status == SubmissionStatus.success,
  );
  expect(controller.isEditable, status == SubmissionStatus.editing);
  expect(controller.isSubmitting, status == SubmissionStatus.submitting);
  expect(
    controller.hasUnresolvedSubmission,
    status == SubmissionStatus.failure || status == SubmissionStatus.uncertain,
  );
}
