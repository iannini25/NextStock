import 'package:flutter/material.dart';
import 'screens/produtos_screen.dart';
import 'screens/categorias_screen.dart';

// cores da marca
const corNavy = Color(0xFF1E293B);
const corAzul = Color(0xFF2563EB);

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NextStock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: corAzul, primary: corNavy),
        appBarTheme: const AppBarTheme(
            backgroundColor: corNavy, foregroundColor: Colors.white),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: corAzul,
          foregroundColor: Colors.white,
        ),
      ),
      home: const Inicio(),
    );
  }
}

// tela base com as duas abas embaixo
class Inicio extends StatefulWidget {
  const Inicio({super.key});

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  int aba = 0;
  final telas = const [ProdutosScreen(), CategoriasScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: telas[aba],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: aba,
        selectedItemColor: corAzul,
        onTap: (i) => setState(() => aba = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Produtos'),
          BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Categorias'),
        ],
      ),
    );
  }
}
