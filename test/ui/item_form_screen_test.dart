import 'dart:async';

import 'package:achados_perdidos/app.dart';
import 'package:achados_perdidos/models/lost_item.dart';
import 'package:achados_perdidos/ui/screens/item_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_lost_item_repository.dart';

void main() {
  testWidgets('opens the form from the create button', (tester) async {
    final repository = FakeLostItemRepository();

    await openForm(tester, repository);

    expect(find.byType(ItemFormScreen), findsOneWidget);
    for (final label in [
      'Nome do objeto',
      'Descrição',
      'Local',
      'Situação',
      'Perdido',
      'Encontrado',
      'Salvar',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(repository.createCalls, isEmpty);
  });

  for (final value in ['', '   ']) {
    testWidgets(
      'rejects ${value.isEmpty ? 'empty' : 'whitespace only'} fields before sending',
      (tester) async {
        final repository = FakeLostItemRepository();
        await openForm(tester, repository);
        if (value.isNotEmpty) {
          for (var index = 0; index < 3; index++) {
            await tester.enterText(find.byType(TextFormField).at(index), value);
          }
        }

        await tapSave(tester);
        await tester.pumpAndSettle();

        for (final message in [
          'Informe o nome do objeto.',
          'Informe a descrição.',
          'Informe o local.',
          'Selecione a situação.',
        ]) {
          expect(find.text(message), findsOneWidget);
        }
        expect(repository.generatedIds, isEmpty);
        expect(repository.createCalls, isEmpty);
      },
    );
  }

  testWidgets('trims input and disables saving and fields during submission', (
    tester,
  ) async {
    final repository = FakeLostItemRepository();
    final response = Completer<void>();
    repository.createCompleters.add(response);
    await openForm(tester, repository);
    await fillForm(tester);

    await tapSave(tester);
    await tester.pump();

    expect(repository.generatedIds, ['item-1']);
    expect(repository.createCalls, [
      (
        id: 'item-1',
        draft: const LostItemDraft(
          name: 'Caderno',
          description: 'Capa azul',
          location: 'Biblioteca',
          status: ItemStatus.lost,
        ),
      ),
    ]);
    final saveButton = find.widgetWithText(FilledButton, 'Salvando...');
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      expect(field.enabled, isFalse);
    }
    await tester.tap(find.text('Encontrado'), warnIfMissed: false);
    await tester.pump();
    final statusSelector = find.byType(SegmentedButton<ItemStatus>);
    expect(
      tester.widget<SegmentedButton<ItemStatus>>(statusSelector).selected,
      {ItemStatus.lost},
    );
    tester
        .widget<SegmentedButton<ItemStatus>>(statusSelector)
        .onSelectionChanged!({ItemStatus.found});
    await tester.pump();
    expect(
      tester.widget<SegmentedButton<ItemStatus>>(statusSelector).selected,
      {ItemStatus.lost},
    );
    expect(
      tester
          .widgetList<ExcludeFocus>(
            find.ancestor(
              of: statusSelector,
              matching: find.byType(ExcludeFocus),
            ),
          )
          .first
          .excluding,
      isTrue,
    );
    await tester.tap(saveButton);
    await tester.pump();
    expect(repository.createCalls, hasLength(1));

    response.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shows error actions and retries the preserved operation', (
    tester,
  ) async {
    final repository = FakeLostItemRepository()
      ..createError = StateError('create failed');
    await openForm(tester, repository);
    await fillForm(tester);

    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Não foi possível salvar. Verifique sua conexão e tente novamente.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Descartar'), findsOneWidget);
    expect(find.textContaining('create failed'), findsNothing);
    repository.createError = null;
    await tester.ensureVisible(find.text('Tentar novamente'));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.generatedIds, ['item-1']);
    expect(repository.createCalls, hasLength(2));
    expect(repository.createCalls.last, repository.createCalls.first);
    expect(find.byType(ItemFormScreen), findsNothing);
    expect(find.text('Objeto cadastrado.'), findsOneWidget);
  });

  testWidgets('returns to the list after success and reloads the saved item', (
    tester,
  ) async {
    final repository = FakeLostItemRepository();
    final response = Completer<void>();
    repository.createCompleters.add(response);
    await openForm(tester, repository);
    await fillForm(tester, statusLabel: 'Encontrado');
    await tapSave(tester);
    await tester.pump();
    repository.items = [
      const LostItem(
        id: 'item-1',
        name: 'Caderno',
        description: 'Capa azul',
        location: 'Biblioteca',
        status: ItemStatus.found,
        createdAt: null,
      ),
    ];

    response.complete();
    await tester.pumpAndSettle();

    expect(repository.createCalls, hasLength(1));
    expect(repository.createCalls.single.draft.status, ItemStatus.found);
    expect(repository.fetchCallCount, 2);
    expect(find.byType(ItemFormScreen), findsNothing);
    expect(find.text('Achados e Perdidos'), findsOneWidget);
    expect(find.text('Caderno'), findsOneWidget);
    expect(find.text('Encontrado'), findsOneWidget);
    expect(find.text('Objeto cadastrado.'), findsOneWidget);
  });

  testWidgets('requires confirmation before discarding a failed submission', (
    tester,
  ) async {
    final repository = FakeLostItemRepository()
      ..createError = StateError('create failed');
    await openForm(tester, repository);
    await fillForm(tester);
    await tapSave(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Descartar'));
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    expect(find.text('Descartar cadastro?'), findsOneWidget);
    expect(
      find.text(
        'O cadastro pode já ter sido salvo. Atualize a lista para conferir antes de cadastrar de novo.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Continuar aqui'));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
    await tester.pumpAndSettle();

    expect(find.text('Salvar'), findsOneWidget);
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      expect(field.enabled, isTrue);
    }
    expect(repository.createCalls, hasLength(1));
    expect(find.byType(ItemFormScreen), findsOneWidget);
  });
}

Future<void> openForm(
  WidgetTester tester,
  FakeLostItemRepository repository,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(LostAndFoundApp(repository: repository));
  await tester.pumpAndSettle();
  await tester.tap(
    find.widgetWithText(FloatingActionButton, 'Cadastrar objeto'),
  );
  await tester.pumpAndSettle();
}

Future<void> fillForm(
  WidgetTester tester, {
  String statusLabel = 'Perdido',
}) async {
  final values = ['  Caderno  ', '  Capa azul  ', '  Biblioteca  '];
  for (var index = 0; index < values.length; index++) {
    await tester.enterText(find.byType(TextFormField).at(index), values[index]);
  }
  tester.testTextInput.hide();
  await tester.pump();
  await tester.ensureVisible(find.text(statusLabel));
  await tester.tap(find.text(statusLabel));
  await tester.pump();
}

Future<void> tapSave(WidgetTester tester) async {
  tester.testTextInput.hide();
  await tester.pump();
  await tester.ensureVisible(find.text('Salvar'));
  await tester.tap(find.text('Salvar'));
}
