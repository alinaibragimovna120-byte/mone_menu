// Mone Menu — техкарты и меню (импорт из Excel).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'provider/menu_provider.dart';
import 'services/card_storage.dart';
import 'services/menu_sync.dart';
import 'ui/home_page.dart';
import 'ui/l10n.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = CardStorage();
  final settings = await storage.loadSettings();
  final menu = MenuProvider(storage)..load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: menu),
        ChangeNotifierProvider(
          create: (_) => LangController(
            saved: settings['lang'] as String?,
            // Свежие настройки: в них же хранится вход на сервер (MenuSync).
            onSave: (code) async => storage.saveSettings({...await storage.loadSettings(), 'lang': code}),
          ),
        ),
        ChangeNotifierProvider(create: (_) => MenuSync(storage: storage, menu: menu, settings: settings)),
      ],
      child: const MoneMenuApp(),
    ),
  );
}

class MoneMenuApp extends StatelessWidget {
  const MoneMenuApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LangController>().lang;
    return MaterialApp(
      // Смена языка пересобирает весь интерфейс с новыми надписями.
      key: ValueKey(lang),
      title: 'Mone Menu',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: Locale(lang.name),
      supportedLocales: const [Locale('ru'), Locale('uz')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomePage(),
    );
  }
}
