import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shell/entrada.dart';

// cores da marca
const corNavy = Color(0xFF122540);
const corAzul = Color(0xFF0066FF);
// laranja mais escuro pra texto de aviso (o laranja normal some no fundo branco)
const corAviso = Color(0xFFE65100);

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
  // cards: no claro ficam brancos com uma borda azulada fraquinha, assim o
  // texto fica mais facil de ler; no escuro ficam mais claros que o fundo.
  final corCard = claro ? Colors.white : const Color(0xFF1E2A3D);
  final corBordaCard =
      claro ? const Color(0xFFD3E2F8) : const Color(0xFF34435C);
  // cor dos campos de texto
  final corCampo = claro ? Colors.white : const Color(0xFF162133);
  final corBordaCampo =
      claro ? const Color(0xFFB8C7DC) : const Color(0xFF3A4A63);
  final corBotao = claro ? corNavy : corAzul;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: fundo,
    cardTheme: CardThemeData(
      color: corCard,
      // no claro so a borda ja separa o card do fundo, sem sombra
      elevation: claro ? 0 : 1,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: claro ? 0.12 : 0.40),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: corBordaCard, width: 1),
      ),
    ),
    // a barra de titulo de cada tela fica da cor da pagina, assim nao parece
    // uma segunda barra embaixo da barra da marca
    appBarTheme: AppBarTheme(
      backgroundColor: fundo,
      foregroundColor: claro ? corNavy : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: claro ? corNavy : Colors.white,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: corAzul,
      foregroundColor: Colors.white,
    ),
    // campos de texto com cantos arredondados e fundo preenchido
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: corCampo,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: corBordaCampo),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: corAzul, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    ),
    // botao principal (salvar, entrar...) mais destacado
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: corBotao,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    // nome do item um pouco mais forte que o texto de baixo
    listTileTheme: const ListTileThemeData(
      titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide(color: corBordaCard),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: DividerThemeData(
      color: claro ? const Color(0xFFDDE3EC) : const Color(0xFF2A3850),
    ),
  );
}
