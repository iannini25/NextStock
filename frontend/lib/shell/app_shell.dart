import 'package:flutter/material.dart';
import '../main.dart';
import '../models/usuario.dart';
import '../services/sessao.dart';
import '../screens/inicio_screen.dart';
import '../screens/produtos_screen.dart';
import '../screens/alertas_screen.dart';
import '../screens/assistente_screen.dart';
import '../screens/categorias_screen.dart';
import '../screens/vendas_screen.dart';
import '../screens/eventos_screen.dart';
import '../screens/previsao_screen.dart';
import '../screens/compras_screen.dart';
import '../screens/reposicao_screen.dart';
import '../screens/painel_screen.dart';
import '../screens/recomendacoes_screen.dart';
import '../screens/relatorios_screen.dart';
import '../screens/importar_erp_screen.dart';
import '../screens/empresa_screen.dart';
import '../screens/usuarios_screen.dart';

// largura minima pra usar a barra lateral fixa (senao vira menu/drawer)
const double larguraDesktop = 900;

// item do menu (icone + titulo). a ordem aqui e a mesma usada no corpo.
class ItemNav {
  final IconData icone;
  final String titulo;
  const ItemNav(this.icone, this.titulo);
}

const List<ItemNav> modulosNav = [
  ItemNav(Icons.home, 'Início'),
  ItemNav(Icons.inventory_2, 'Produtos'),
  ItemNav(Icons.notifications, 'Alertas'),
  ItemNav(Icons.smart_toy, 'Assistente'),
  ItemNav(Icons.category, 'Categorias'),
  ItemNav(Icons.point_of_sale, 'Vendas'),
  ItemNav(Icons.event, 'Eventos'),
  ItemNav(Icons.trending_up, 'Previsão'),
  ItemNav(Icons.shopping_cart, 'Compras'),
  ItemNav(Icons.autorenew, 'Reposição'),
  ItemNav(Icons.dashboard, 'Painel'),
  ItemNav(Icons.lightbulb, 'Recomendações'),
  ItemNav(Icons.bar_chart, 'Relatórios'),
  ItemNav(Icons.cloud_upload, 'Importar'),
  ItemNav(Icons.business, 'Empresa'),
  ItemNav(Icons.people, 'Usuários'),
];

// casca do app: barra de cima com a marca + navegacao (lateral no desktop,
// drawer no celular) + a tela do modulo selecionado no meio.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selecionado = 0;

  void _selecionar(int i) => setState(() => selecionado = i);

  // monta a tela conforme o indice do menu
  Widget _corpo() {
    switch (selecionado) {
      case 1:
        return const ProdutosScreen();
      case 2:
        return const AlertasScreen();
      case 3:
        return const AssistenteScreen();
      case 4:
        return const CategoriasScreen();
      case 5:
        return const VendasScreen();
      case 6:
        return const EventosScreen();
      case 7:
        return const PrevisaoScreen();
      case 8:
        return const ComprasScreen();
      case 9:
        return const ReposicaoScreen();
      case 10:
        return const PainelScreen();
      case 11:
        return const RecomendacoesScreen();
      case 12:
        return const RelatoriosScreen();
      case 13:
        return const ImportarErpScreen();
      case 14:
        return const EmpresaScreen();
      case 15:
        return const UsuariosScreen();
      default:
        return InicioScreen(aoAbrir: _selecionar);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricoes) {
        final desktop = restricoes.maxWidth >= larguraDesktop;
        if (desktop) return _layoutDesktop();
        return _layoutCelular();
      },
    );
  }

  // desktop: barra de cima + [lateral | conteudo]
  Widget _layoutDesktop() {
    return Scaffold(
      body: Column(
        children: [
          const BarraTopo(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BarraLateral(selecionado: selecionado, aoSelecionar: _selecionar),
                const VerticalDivider(width: 1),
                Expanded(child: _corpo()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // celular: barra de cima com botao de menu + drawer + conteudo
  Widget _layoutCelular() {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: _ListaModulos(
            selecionado: selecionado,
            aoSelecionar: (i) {
              Navigator.pop(context);
              _selecionar(i);
            },
          ),
        ),
      ),
      body: Column(
        children: [
          Builder(
            builder: (ctx) => BarraTopo(
              aoAbrirMenu: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          Expanded(child: _corpo()),
        ],
      ),
    );
  }
}

// barra fina no topo: marca (logo + nome) e o botao de tema.
// no claro o fundo e claro e a logo navy aparece; no escuro o fundo
// escurece e a logo vira branca pra nao sumir.
class BarraTopo extends StatelessWidget {
  final VoidCallback? aoAbrirMenu;
  const BarraTopo({super.key, this.aoAbrirMenu});

  Widget _marca(bool escuro, String asset, double altura) {
    final imagem = Image.asset(asset, height: altura);
    if (!escuro) return imagem;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      child: imagem,
    );
  }

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    // claro: branco (igual ao fundo). escuro: azul escuro medio pra ver a logo.
    final corBarra = escuro ? const Color(0xFF1D3A63) : Colors.white;
    final corIcone = escuro ? Colors.white : corNavy;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      color: corBarra,
      child: Material(
        color: Colors.transparent,
        elevation: 2,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                if (aoAbrirMenu != null)
                  IconButton(
                    icon: Icon(Icons.menu, color: corIcone),
                    onPressed: aoAbrirMenu,
                  )
                else
                  const SizedBox(width: 16),
                _marca(escuro, 'assets/logo.png', 40),
                const SizedBox(width: 10),
                _marca(escuro, 'assets/nome.png', 30),
                const Spacer(),
                // quem esta logado + botao de sair (o nome encolhe com reticencias em tela pequena)
                Flexible(
                  child: ValueListenableBuilder<Usuario?>(
                    valueListenable: Sessao.usuario,
                    builder: (_, usuario, _) {
                      if (usuario == null) return const SizedBox.shrink();
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              usuario.nome,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: corIcone, fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Sair',
                            icon: Icon(Icons.logout, color: corIcone),
                            onPressed: () => Sessao.sair(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: modoTema,
                  builder: (_, modo, _) {
                    final estaEscuro = modo == ThemeMode.dark;
                    return IconButton(
                      tooltip: estaEscuro ? 'Tema claro' : 'Tema escuro',
                      icon: Icon(
                        estaEscuro ? Icons.light_mode : Icons.dark_mode,
                        color: corIcone,
                      ),
                      onPressed: alternarTema,
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// barra lateral fixa do desktop
class _BarraLateral extends StatelessWidget {
  final int selecionado;
  final ValueChanged<int> aoSelecionar;
  const _BarraLateral({required this.selecionado, required this.aoSelecionar});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: Theme.of(context).colorScheme.surface,
      child: _ListaModulos(selecionado: selecionado, aoSelecionar: aoSelecionar),
    );
  }
}

// lista de modulos usada tanto na lateral quanto no drawer
class _ListaModulos extends StatelessWidget {
  final int selecionado;
  final ValueChanged<int> aoSelecionar;
  const _ListaModulos({required this.selecionado, required this.aoSelecionar});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: modulosNav.length,
      itemBuilder: (_, i) {
        final m = modulosNav[i];
        final sel = i == selecionado;
        return ListTile(
          leading: Icon(m.icone, color: sel ? corAzul : null),
          title: Text(
            m.titulo,
            style: TextStyle(
              color: sel ? corAzul : null,
              fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          selected: sel,
          selectedTileColor: corAzul.withValues(alpha: 0.10),
          onTap: () => aoSelecionar(i),
        );
      },
    );
  }
}
