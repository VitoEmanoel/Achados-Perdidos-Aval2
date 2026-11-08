import 'dart:async';

import 'package:achados_perdidos/app.dart';
import 'package:achados_perdidos/data/lost_item_repository.dart';
import 'package:achados_perdidos/models/lost_item.dart';
import 'package:achados_perdidos/ui/screens/item_detail_screen.dart';
import 'package:achados_perdidos/ui/screens/item_form_screen.dart';
import 'package:achados_perdidos/ui/widgets/lost_item_card.dart';
import 'package:achados_perdidos/ui/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_lost_item_repository.dart';

void main() {
  final createdAt = DateTime(2026, 11, 5, 14, 30);
  final lostItem = LostItem(
    id: 'existing-item',
    name: 'Caderno',
    description: 'Capa azul',
    location: 'Biblioteca',
    status: ItemStatus.lost,
    createdAt: createdAt,
  );
  final foundItem = LostItem(
    id: 'existing-item',
    name: 'Caderno',
    description: 'Capa azul',
    location: 'Biblioteca',
    status: ItemStatus.found,
    createdAt: createdAt,
  );
  const editedDraft = LostItemDraft(
    name: 'Livro',
    description: 'Capa verde',
    location: 'Bloco B',
    status: ItemStatus.lost,
  );

  for (final item in [lostItem, foundItem]) {
    testWidgets('opens ${item.status.name} item details from its card', (
      tester,
    ) async {
      final repository = FakeLostItemRepository(items: [item]);

      await openDetails(tester, repository);

      for (final text in [
        'Detalhes do objeto',
        'Caderno',
        'Local',
        'Biblioteca',
        'Descrição',
        'Capa azul',
        'Cadastrado em',
        '05/11/2026 às 14:30',
        'Editar',
        'Excluir',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      final badge = find.byType(StatusBadge);
      expect(badge, findsOneWidget);
      expect(tester.widget<StatusBadge>(badge).status, item.status);
      expect(
        find.descendant(
          of: badge,
          matching: find.text(
            item.status == ItemStatus.lost ? 'Perdido' : 'Encontrado',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: badge,
          matching: find.byIcon(
            item.status == ItemStatus.lost
                ? Icons.search
                : Icons.check_circle_outline,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Marcar como encontrado'),
        item.status == ItemStatus.lost ? findsOneWidget : findsNothing,
      );
      expect(repository.fetchCallCount, 1);
      expect(repository.markAsFoundCalls, isEmpty);
      expect(repository.updateCalls, isEmpty);
      expect(repository.deleteCalls, isEmpty);
    });

    testWidgets('opens a prefilled editor for ${item.status.name}', (
      tester,
    ) async {
      final repository = FakeLostItemRepository(items: [item]);
      await openDetails(tester, repository);

      await tapText(tester, 'Editar');
      await tester.pumpAndSettle();

      expect(find.text('Editar objeto'), findsOneWidget);
      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields, hasLength(3));
      expect(fields.map((field) => field.controller!.text), [
        'Caderno',
        'Capa azul',
        'Biblioteca',
      ]);
      expect(
        tester
            .widget<SegmentedButton<ItemStatus>>(
              find.byType(SegmentedButton<ItemStatus>),
            )
            .selected,
        {item.status},
      );
      expect(repository.markAsFoundCalls, isEmpty);
      expect(repository.updateCalls, isEmpty);
      expect(repository.createCalls, isEmpty);
      expect(repository.generatedIds, isEmpty);
    });
  }

  testWidgets('returns from details without reloading or changing the item', (
    tester,
  ) async {
    final repository = FakeLostItemRepository(items: [lostItem]);
    await openDetails(tester, repository);

    await tester.tap(find.byType(BackButtonIcon));
    await tester.pumpAndSettle();

    expect(find.byType(ItemDetailScreen), findsNothing);
    expect(find.byType(LostItemCard), findsOneWidget);
    expect(repository.fetchCallCount, 1);
    expect(repository.markAsFoundCalls, isEmpty);
    expect(repository.updateCalls, isEmpty);
    expect(repository.deleteCalls, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('canceling the delete confirmation does not delete', (
    tester,
  ) async {
    final repository = FakeLostItemRepository(items: [lostItem]);
    await openDetails(tester, repository);

    await tapText(tester, 'Excluir');
    await tester.pumpAndSettle();

    expect(find.text('Excluir objeto?'), findsOneWidget);
    expect(find.text('Esta ação não pode ser desfeita.'), findsOneWidget);
    expect(repository.deleteCalls, isEmpty);
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Detalhes do objeto'), findsOneWidget);
    expect(repository.deleteCalls, isEmpty);
    expect(repository.fetchCallCount, 1);
  });

  for (final isDeleting in [false, true]) {
    final actionName = isDeleting ? 'delete' : 'mark as found';
    final successMessage = isDeleting
        ? 'Objeto excluído.'
        : 'Objeto marcado como encontrado.';

    testWidgets(
      '$actionName blocks controls then returns and reloads on success',
      (tester) async {
        final repository = FakeLostItemRepository(items: [lostItem]);
        final response = Completer<void>();
        (isDeleting
                ? repository.deleteCompleters
                : repository.markAsFoundCompleters)
            .add(response);
        await openDetails(tester, repository);

        await startDetailAction(tester, isDeleting: isDeleting);
        await tester.pump();

        expectRunningControls(
          tester,
          isDeleting ? 'Excluindo...' : 'Salvando...',
        );
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.text('Detalhes do objeto'), findsOneWidget);
        expect(repository.fetchCallCount, 1);
        expect(
          repository.deleteCalls,
          isDeleting ? ['existing-item'] : isEmpty,
        );
        expect(
          repository.markAsFoundCalls,
          isDeleting ? isEmpty : ['existing-item'],
        );
        expect(repository.updateCalls, isEmpty);
        expect(repository.createCalls, isEmpty);
        expect(repository.generatedIds, isEmpty);
        if (isDeleting) {
          repository.items = [];
        }

        response.complete();
        await tester.pumpAndSettle();

        expect(find.byType(ItemDetailScreen), findsNothing);
        expect(find.text('Achados e Perdidos'), findsOneWidget);
        expect(find.text(successMessage), findsOneWidget);
        expect(repository.fetchCallCount, 2);
        expect(repository.updateCalls, isEmpty);
        expect(
          find.byType(LostItemCard),
          isDeleting ? findsNothing : findsOneWidget,
        );
        if (!isDeleting) {
          expect(find.text('Encontrado'), findsOneWidget);
          expect(find.text('Perdido'), findsNothing);
        }
      },
    );

    for (final retry in [false, true]) {
      testWidgets(
        '$actionName offers retry and cancel after failure and ${retry ? 'retries' : 'cancels'}',
        (tester) async {
          final repository = FakeLostItemRepository(items: [lostItem]);
          if (isDeleting) {
            repository.deleteError = StateError('delete failed');
          } else {
            repository.markAsFoundError = StateError('mark as found failed');
          }
          await openDetails(tester, repository);

          await startDetailAction(tester, isDeleting: isDeleting);
          await tester.pumpAndSettle();

          expect(
            find.text(
              isDeleting
                  ? 'Não foi possível excluir. Verifique sua conexão e tente novamente.'
                  : 'Não foi possível salvar. Verifique sua conexão e tente novamente.',
            ),
            findsOneWidget,
          );
          expect(find.text('Tentar novamente'), findsOneWidget);
          expect(find.text('Cancelar'), findsOneWidget);
          expect(find.textContaining('failed'), findsNothing);
          expect(repository.fetchCallCount, 1);
          expect(repository.updateCalls, isEmpty);
          expect(repository.items.single.status, ItemStatus.lost);
          repository.deleteError = null;
          repository.markAsFoundError = null;
          if (isDeleting && retry) {
            repository.items = [];
          }

          await tapText(tester, retry ? 'Tentar novamente' : 'Cancelar');
          await tester.pumpAndSettle();

          expect(
            repository.deleteCalls,
            isDeleting ? List.filled(retry ? 2 : 1, 'existing-item') : isEmpty,
          );
          expect(
            repository.markAsFoundCalls,
            isDeleting ? isEmpty : List.filled(retry ? 2 : 1, 'existing-item'),
          );
          expect(repository.updateCalls, isEmpty);
          if (retry) {
            expect(find.byType(ItemDetailScreen), findsNothing);
            expect(find.text(successMessage), findsOneWidget);
            expect(repository.fetchCallCount, 2);
            if (!isDeleting) {
              expect(find.text('Encontrado'), findsOneWidget);
            }
          } else {
            expect(find.text('Detalhes do objeto'), findsOneWidget);
            expect(find.text('Editar'), findsOneWidget);
            expect(find.text('Excluir'), findsOneWidget);
            expect(find.text('Marcar como encontrado'), findsOneWidget);
            expect(find.text('Tentar novamente'), findsNothing);
            expect(find.byType(SnackBar), findsNothing);
            expect(repository.fetchCallCount, 1);
          }
        },
      );
    }

    testWidgets('$actionName shows uncertainty on timeout and can retry', (
      tester,
    ) async {
      final repository = FakeLostItemRepository(items: [lostItem]);
      final response = Completer<void>();
      (isDeleting
              ? repository.deleteCompleters
              : repository.markAsFoundCompleters)
          .add(response);
      await openDetails(tester, repository);
      await startDetailAction(tester, isDeleting: isDeleting);
      await tester.pump();

      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();

      expect(
        find.text(
          isDeleting
              ? 'Não foi possível confirmar a exclusão. Verifique sua conexão e tente novamente.'
              : 'Não foi possível confirmar a alteração. Verifique sua conexão e tente novamente.',
        ),
        findsOneWidget,
      );
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      response.complete();
      await tester.pumpAndSettle();
      expect(find.text('Detalhes do objeto'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      if (isDeleting) {
        repository.items = [];
      }

      await tapText(tester, 'Tentar novamente');
      await tester.pumpAndSettle();

      expect(find.text(successMessage), findsOneWidget);
      expect(repository.fetchCallCount, 2);
      expect(
        repository.deleteCalls,
        isDeleting ? ['existing-item', 'existing-item'] : isEmpty,
      );
      expect(
        repository.markAsFoundCalls,
        isDeleting ? isEmpty : ['existing-item', 'existing-item'],
      );
      expect(repository.updateCalls, isEmpty);
      if (!isDeleting) {
        expect(find.text('Encontrado'), findsOneWidget);
      }
    });
  }

  testWidgets(
    'marking as found preserves concurrent edits in the refreshed list',
    (tester) async {
      final displayedItem = LostItem(
        id: lostItem.id,
        name: lostItem.name,
        description: lostItem.description,
        location: 'Sala 12',
        status: ItemStatus.lost,
        createdAt: createdAt,
      );
      final repository = FakeLostItemRepository(items: [displayedItem]);
      await openDetails(tester, repository);
      expect(find.text('Sala 12'), findsOneWidget);
      expect(find.text('Perdido'), findsOneWidget);
      repository.items = [
        LostItem(
          id: displayedItem.id,
          name: 'Livro',
          description: 'Capa verde',
          location: 'Secretaria',
          status: ItemStatus.lost,
          createdAt: createdAt,
        ),
      ];

      await tapText(tester, 'Marcar como encontrado');
      await tester.pumpAndSettle();

      expect(find.byType(ItemDetailScreen), findsNothing);
      expect(find.text('Achados e Perdidos'), findsOneWidget);
      expect(find.text('Objeto marcado como encontrado.'), findsOneWidget);
      expect(find.text('Secretaria'), findsOneWidget);
      expect(find.text('Encontrado'), findsOneWidget);
      expect(find.text('Sala 12'), findsNothing);
      expect(find.text('Perdido'), findsNothing);
      expect(repository.fetchCallCount, 2);
      expect(repository.markAsFoundCalls, [displayedItem.id]);
      expect(repository.updateCalls, isEmpty);
      expect(repository.deleteCalls, isEmpty);
      expect(repository.createCalls, isEmpty);
      expect(repository.generatedIds, isEmpty);
      final card = tester.widget<LostItemCard>(find.byType(LostItemCard));
      expect(card.item.id, displayedItem.id);
      expect(card.item.name, 'Livro');
      expect(card.item.description, 'Capa verde');
      expect(card.item.location, 'Secretaria');
      expect(card.item.status, ItemStatus.found);
      expect(card.item.createdAt, createdAt);
    },
  );

  testWidgets('saving edits updates once and returns to the refreshed list', (
    tester,
  ) async {
    final repository = FakeLostItemRepository(items: [foundItem]);
    final response = Completer<void>();
    repository.updateCompleters.add(response);
    await openDetails(tester, repository);
    await tapText(tester, 'Editar');
    await tester.pumpAndSettle();
    await fillEditor(tester);

    await tapText(tester, 'Salvar');
    await tester.pump();

    expectRunningControls(tester, 'Salvando...');
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      expect(field.enabled, isFalse);
    }
    final selector = find.byType(SegmentedButton<ItemStatus>);
    expect(tester.widget<SegmentedButton<ItemStatus>>(selector).selected, {
      ItemStatus.lost,
    });
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .ancestor(of: selector, matching: find.byType(IgnorePointer))
                .first,
          )
          .ignoring,
      isTrue,
    );
    await tester.tap(find.text('Salvando...'));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Editar objeto'), findsOneWidget);
    expect(repository.updateCalls, [(id: foundItem.id, draft: editedDraft)]);
    expect(repository.createCalls, isEmpty);
    expect(repository.generatedIds, isEmpty);
    repository.items = [
      LostItem(
        id: foundItem.id,
        name: 'Livro',
        description: 'Capa verde',
        location: 'Bloco B',
        status: ItemStatus.lost,
        createdAt: createdAt,
      ),
    ];

    response.complete();
    await tester.pumpAndSettle();

    expect(find.byType(ItemFormScreen), findsNothing);
    expect(find.byType(ItemDetailScreen), findsNothing);
    expect(find.text('Objeto atualizado.'), findsOneWidget);
    expect(repository.fetchCallCount, 2);
    expect(repository.updateCalls, hasLength(1));
    expect(repository.markAsFoundCalls, isEmpty);
    final card = tester.widget<LostItemCard>(find.byType(LostItemCard));
    expect(card.item.id, foundItem.id);
    expect(card.item.name, 'Livro');
    expect(card.item.description, 'Capa verde');
    expect(card.item.location, 'Bloco B');
    expect(card.item.status, ItemStatus.lost);
    expect(card.item.createdAt, createdAt);
    expect(find.text('Cadastrado em 05/11/2026 às 14:30'), findsOneWidget);
  });

  testWidgets('editing still validates required fields before updating', (
    tester,
  ) async {
    final repository = FakeLostItemRepository(items: [lostItem]);
    await openDetails(tester, repository);
    await tapText(tester, 'Editar');
    await tester.pumpAndSettle();
    for (var index = 0; index < 3; index++) {
      await tester.enterText(find.byType(TextFormField).at(index), '   ');
    }
    tester.testTextInput.hide();
    await tester.pump();

    await tapText(tester, 'Salvar');
    await tester.pumpAndSettle();

    expect(find.text('Informe o nome do objeto.'), findsOneWidget);
    expect(find.text('Informe a descrição.'), findsOneWidget);
    expect(find.text('Informe o local.'), findsOneWidget);
    expect(find.text('Editar objeto'), findsOneWidget);
    expect(repository.updateCalls, isEmpty);
    expect(repository.markAsFoundCalls, isEmpty);
    expect(repository.createCalls, isEmpty);
    expect(repository.generatedIds, isEmpty);
  });

  testWidgets(
    'editing a removed item shows an error and retries the same update',
    (tester) async {
      final repository = FakeLostItemRepository(items: [lostItem])
        ..updateError = ItemNotFoundException(lostItem.id);
      await openDetails(tester, repository);
      await tapText(tester, 'Editar');
      await tester.pumpAndSettle();
      await fillEditor(tester);
      await tapText(tester, 'Salvar');
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Não foi possível salvar. Verifique sua conexão e tente novamente.',
        ),
        findsOneWidget,
      );
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.text('Descartar'), findsOneWidget);
      expect(find.textContaining('ItemNotFoundException'), findsNothing);
      expect(repository.fetchCallCount, 1);
      expect(find.text('Editar objeto'), findsOneWidget);
      repository.updateError = null;

      await tapText(tester, 'Tentar novamente');
      await tester.pumpAndSettle();

      expect(repository.updateCalls, [
        (id: lostItem.id, draft: editedDraft),
        (id: lostItem.id, draft: editedDraft),
      ]);
      expect(repository.markAsFoundCalls, isEmpty);
      expect(repository.createCalls, isEmpty);
      expect(repository.generatedIds, isEmpty);
      expect(find.text('Objeto atualizado.'), findsOneWidget);
      expect(repository.fetchCallCount, 2);
    },
  );
}

Future<void> openDetails(
  WidgetTester tester,
  FakeLostItemRepository repository,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(LostAndFoundApp(repository: repository));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(LostItemCard));
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
}

Future<void> startDetailAction(
  WidgetTester tester, {
  required bool isDeleting,
}) async {
  await tapText(tester, isDeleting ? 'Excluir' : 'Marcar como encontrado');
  if (isDeleting) {
    await tester.pumpAndSettle();
    expect(find.text('Excluir objeto?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void expectRunningControls(WidgetTester tester, String label) {
  expect(find.text(label), findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  expect(
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, label))
        .onPressed,
    isNull,
  );
  final back = find.ancestor(
    of: find.byType(BackButtonIcon),
    matching: find.byType(IconButton),
  );
  expect(tester.widget<IconButton>(back).onPressed, isNull);
  expect(
    tester.widget<PopScope<Object?>>(find.byType(PopScope<Object?>)).canPop,
    isFalse,
  );
  expect(find.text('Editar'), findsNothing);
  expect(find.text('Excluir'), findsNothing);
  expect(find.text('Marcar como encontrado'), findsNothing);
}

Future<void> fillEditor(WidgetTester tester) async {
  final values = ['  Livro  ', '  Capa verde  ', '  Bloco B  '];
  for (var index = 0; index < values.length; index++) {
    await tester.enterText(find.byType(TextFormField).at(index), values[index]);
  }
  tester.testTextInput.hide();
  await tester.pump();
  final selector = tester.widget<SegmentedButton<ItemStatus>>(
    find.byType(SegmentedButton<ItemStatus>),
  );
  if (!selector.selected.contains(ItemStatus.lost)) {
    await tapText(tester, 'Perdido');
    await tester.pump();
  }
}
