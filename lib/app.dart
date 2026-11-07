import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/lost_item_repository.dart';
import 'state/lost_items_controller.dart';
import 'ui/screens/item_list_screen.dart';

class LostAndFoundApp extends StatelessWidget {
  const LostAndFoundApp({super.key, required this.repository});

  final LostItemRepository repository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LostItemRepository>.value(value: repository),
        ChangeNotifierProvider(
          create: (_) => LostItemsController(repository)..loadItems(),
        ),
      ],
      child: MaterialApp(
        title: 'Achados e Perdidos',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
          ),
        ),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const ItemListScreen(),
      ),
    );
  }
}
