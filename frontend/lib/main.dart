import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shell/entrada.dart';

// cores da marca
const corNavy = Color(0xFF122540);
const corAzul = Color(0xFF0066FF);

// chave usada pra guardar a preferencia de tema
const _kTemaEscuro = 'tema_escuro';

// notifica o app quando o tema muda (claro/escuro)
final ValueNotifier<ThemeMode> modoTema = ValueNotifier(ThemeMode.light);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final escuro = prefs.getBool(_kTemaEscuro) ?? false;
  modoTema.value = escuro ? ThemeMode.dark : ThemeMode.light;
  runApp(const App());
}

// alterna entre claro e escuro e salva a escolha
Future<void> alternarTema() async {
  final escuro = modoTema.value != ThemeMode.dark;
  modoTema.value = escuro ? ThemeMode.dark : ThemeMode.light;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kTemaEscuro, escuro);
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: modoTema,
      builder: (_, modo, _) {
        return MaterialApp(
          title: 'NextStock',
          debugShowCheckedModeBanner: false,
          themeMode: modo,
          theme: _tema(Brightness.light),
          darkTheme: _tema(Brightness.dark),
          // anima a troca de tema (claro/escuro) pra nao dar um pulo seco
          themeAnimationDuration: const Duration(milliseconds: 280),
          themeAnimationCurve: Curves.easeInOut,
          // decide entre configuracao inicial, login e o app
          home: const Entrada(),
        );
      },
    );
  }
}

// monta o tema. os cards ficam numa cor um pouco diferente do fundo
// pra destacarem da pagina.
ThemeData _tema(Brightness brilho) {
  final claro = brilho == Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: corAzul,
    brightness: brilho,
    primary: claro ? corNavy : corAzul,
  );
  final fundo = claro ? const Color(0xFFF3F5F9) : const Color(0xFF0E1522);
  // cards: no claro um azul mais forte com borda pra dar bastante contraste
  // no fundo cinza-claro; no escuro ficam mais claros que o fundo.
  final corCard = claro ? const Color(0xFFC5DCFF) : const Color(0xFF1E2A3D);
  final corBordaCard =
      claro ? const Color(0xFF8AB4F8) : const Color(0xFF34435C);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: fundo,
    cardTheme: CardThemeData(
      color: corCard,
      elevation: claro ? 3 : 1,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: claro ? 0.20 : 0.40),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: corBordaCard, width: 1),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: claro ? Colors.white : const Color(0xFF12203A),
      foregroundColor: claro ? corNavy : Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: corAzul,
      foregroundColor: Colors.white,
    ),
  );
}
