// Mone Menu — техкарты и меню (импорт из Excel).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'provider/menu_provider.dart';
import 'services/card_storage.dart';
import 'ui/home_page.dart';
import 'ui/l10n.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = CardStorage();
  final settings = await storage.loadSettings();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MenuProvider(storage)..load()),
        ChangeNotifierProvider(
          create: (_) => LangController(
            saved: settings['lang'] as String?,
            onSave: (code) => storage.saveSettings({...settings, 'lang': code}),
          ),
        ),
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
