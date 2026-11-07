import 'dart:async';

import 'package:achados_perdidos/app.dart';
import 'package:achados_perdidos/models/lost_item.dart';
import 'package:achados_perdidos/ui/widgets/lost_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_lost_item_repository.dart';

void main() {
  const lostItem = LostItem(
    id: 'lost-item',
    name: 'Caderno',
    description: 'Capa azul',
    location: 'Biblioteca',
    status: ItemStatus.lost,
    createdAt: null,
  );
  const foundItem = LostItem(
    id: 'found-item',
    name: 'Livro',
    description: 'Capa verde',
    location: 'Bloco B',
    status: ItemStatus.found,
    createdAt: null,
  );
  const emptyMessage =
      'Nenhum objeto cadastrado ainda.\n'
      'Toque em "Cadastrar objeto" para adicionar o primeiro.';
  const errorMessage =
      'Não foi possível carregar os objetos. '
      'Verifique sua conexão e tente novamente.';

  testWidgets('shows progress while the initial fetch is pending', (
    tester,
  ) async {
    final repository = FakeLostItemRepository();
    final response = Completer<List<LostItem>>();
    repository.fetchCompleters.add(response);

    await pumpApp(tester, repository);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Carregando objetos...'), findsOneWidget);
    expect(find.text(emptyMessage), findsNothing);
    response.complete([]);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(emptyMessage), findsOneWidget);
  });

  testWidgets('shows every item field and distinct status labels and icons', (
    tester,
  ) async {
    final repository = FakeLostItemRepository(items: [foundItem, lostItem]);

    await pumpApp(tester, repository);
    await tester.pumpAndSettle();

    final cards = find.byType(LostItemCard);
    expect(cards, findsNWidgets(2));
    for (final entry in [
      (
        index: 0,
        item: foundItem,
        label: 'Encontrado',
        icon: Icons.check_circle_outline,
      ),
      (index: 1, item: lostItem, label: 'Perdido', icon: Icons.search),
    ]) {
      for (final text in [
        entry.item.name,
        entry.item.location,
        entry.item.description,
        entry.label,
      ]) {
        expect(
          find.descendant(of: cards.at(entry.index), matching: find.text(text)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: cards.at(entry.index),
          matching: find.byIcon(entry.icon),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('shows the empty message and the create button', (tester) async {
    await pumpApp(tester, FakeLostItemRepository());
    await tester.pumpAndSettle();

    expect(find.text(emptyMessage), findsOneWidget);
    expect(find.byType(LostItemCard), findsNothing);
    expect(
      find.widgetWithText(FloatingActionButton, 'Cadastrar objeto'),
      findsOneWidget,
    );
  });

  testWidgets('shows a readable error and reloads when retry is tapped', (
    tester,
  ) async {
    final repository = FakeLostItemRepository()
      ..fetchError = StateError('fetch failed');
    await pumpApp(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text(errorMessage), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.textContaining('fetch failed'), findsNothing);
    final response = Completer<List<LostItem>>();
    repository.fetchError = null;
    repository.fetchCompleters.add(response);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();

    expect(repository.fetchCallCount, 2);
    expect(find.text('Carregando objetos...'), findsOneWidget);
    response.complete([lostItem]);
    await tester.pumpAndSettle();
    expect(find.text('Caderno'), findsOneWidget);
    expect(find.text(errorMessage), findsNothing);
  });

  for (final initialState in ['empty', 'error', 'populated']) {
    testWidgets('pull to refresh works with an $initialState list', (
      tester,
    ) async {
      final repository = FakeLostItemRepository(
        items: initialState == 'populated' ? [lostItem] : [],
      );
      if (initialState == 'error') {
        repository.fetchError = StateError('fetch failed');
      }
      await pumpApp(tester, repository);
      await tester.pumpAndSettle();
      final response = Completer<List<LostItem>>();
      repository.fetchError = null;
      repository.fetchCompleters.add(response);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Scrollable)),
      );
      await gesture.moveBy(const Offset(0, 30));
      await gesture.moveBy(const Offset(0, 320));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(repository.fetchCallCount, 2);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      response.complete([foundItem]);
      await tester.pumpAndSettle();
      expect(find.text('Livro'), findsOneWidget);
      expect(find.text('Encontrado'), findsOneWidget);
      expect(find.text(errorMessage), findsNothing);
      expect(find.text(emptyMessage), findsNothing);
    });
  }
}

Future<void> pumpApp(
  WidgetTester tester,
  FakeLostItemRepository repository,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(LostAndFoundApp(repository: repository));
}
