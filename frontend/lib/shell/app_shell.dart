import 'dart:async';

import 'package:flutter/material.dart';
import '../main.dart';
import '../models/alerta.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import '../services/sessao.dart';
import '../screens/inicio_screen.dart';
import '../screens/produtos_screen.dart';
import '../screens/alertas_screen.dart';
import '../screens/assistente_screen.dart';
import '../screens/categorias_screen.dart';
import '../screens/vendas_screen.dart';
import '../screens/movimentacoes_screen.dart';
import '../screens/perdas_screen.dart';
import '../screens/armazenamento_screen.dart';
import '../screens/eventos_screen.dart';
import '../screens/previsao_screen.dart';
import '../screens/compras_screen.dart';
import '../screens/reposicao_screen.dart';
import '../screens/painel_screen.dart';
import '../screens/recomendacoes_screen.dart';
import '../screens/relatorios_screen.dart';
import '../screens/integracao_erp_screen.dart';
import '../screens/empresa_screen.dart';
import '../screens/usuarios_screen.dart';

// largura minima pra usar a barra lateral fixa (senao vira menu/drawer)
const double larguraDesktop = 900;

// item do menu. o id escolhe a tela (nao a posicao, porque o usuario comum nao ve todos os itens)
class ItemNav {
  final String id;
  final IconData icone;
  final String titulo;
  final bool soAdmin;
  const ItemNav(this.id, this.icone, this.titulo, {this.soAdmin = false});
}

const List<ItemNav> modulosNav = [
  ItemNav('inicio', Icons.home, 'Início'),
  ItemNav('produtos', Icons.inventory_2, 'Produtos'),
  ItemNav('alertas', Icons.notifications, 'Alertas'),
  ItemNav('assistente', Icons.smart_toy, 'Assistente'),
  ItemNav('categorias', Icons.category, 'Categorias'),
  ItemNav('vendas', Icons.point_of_sale, 'Vendas'),
  ItemNav('movimentacoes', Icons.swap_vert, 'Movimentações'),
  ItemNav('perdas', Icons.delete_sweep, 'Perdas'),
  ItemNav('armazenamento', Icons.thermostat, 'Armazenamento'),
  ItemNav('eventos', Icons.event, 'Eventos'),
  ItemNav('previsao', Icons.trending_up, 'Previsão'),
  ItemNav('compras', Icons.shopping_cart, 'Compras'),
  ItemNav('reposicao', Icons.autorenew, 'Reposição'),
  ItemNav('painel', Icons.dashboard, 'Painel'),
  ItemNav('recomendacoes', Icons.lightbulb, 'Recomendações'),
  ItemNav('relatorios', Icons.bar_chart, 'Relatórios'),
  ItemNav('erp', Icons.hub, 'Integração ERP', soAdmin: true),
  ItemNav('empresa', Icons.business, 'Empresa'),
  ItemNav('usuarios', Icons.people, 'Usuários', soAdmin: true),
];

// os itens que quem esta logado pode ver
List<ItemNav> modulosVisiveis() => modulosNav.where((m) => !m.soAdmin || Sessao.ehAdmin).toList();

// de quanto em quanto tempo o selo de alertas do menu se atualiza sozinho
const Duration intervaloAlertas = Duration(minutes: 5);

// casca do app: barra de cima com a marca + navegacao (lateral no desktop,
// drawer no celular) + a tela do modulo selecionado no meio.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String selecionado = 'inicio';
  ResumoAlertas? alertas; // selo do item Alertas (null = ainda nao carregou ou deu erro)
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    _atualizarAlertas();
    // aviso proativo: pergunta de novo a cada 5 min. cancelado no dispose (sair do app / logout)
    _relogio = Timer.periodic(intervaloAlertas, (_) => _atualizarAlertas());
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  // erro aqui nao atrapalha o uso do app: o selo so some.
  // 401 (sessao expirou) ja e tratado no ApiService, que volta pro login
  Future<void> _atualizarAlertas() async {
    try {
      final r = await ApiService.resumoAlertas();
      if (mounted) setState(() => alertas = r);
    } catch (_) {
      if (mounted) setState(() => alertas = null);
    }
  }

  void _selecionar(String id) {
    setState(() => selecionado = id);
    if (id == 'alertas' || id == 'armazenamento') _atualizarAlertas(); // o selo bate com o que a tela mostra
  }

  // monta a tela conforme o item escolhido no menu
  Widget _corpo() {
    switch (selecionado) {
      case 'produtos':
        return const ProdutosScreen();
      case 'alertas':
        return AlertasScreen(aoAbrirArmazenamento: () => _selecionar('armazenamento'));
      case 'assistente':
        return const AssistenteScreen();
      case 'categorias':
        return const CategoriasScreen();
      case 'vendas':
        return const VendasScreen();
      case 'movimentacoes':
        return const MovimentacoesScreen();
      case 'perdas':
        return const PerdasScreen();
      case 'armazenamento':
        return const ArmazenamentoScreen();
      case 'eventos':
        return const EventosScreen();
      case 'previsao':
        return const PrevisaoScreen();
      case 'compras':
        return const ComprasScreen();
      case 'reposicao':
        return const ReposicaoScreen();
      case 'painel':
        return const PainelScreen();
      case 'recomendacoes':
        return const RecomendacoesScreen();
      case 'relatorios':
        return const RelatoriosScreen();
      case 'erp':
        return const IntegracaoErpScreen();
      case 'empresa':
        return const EmpresaScreen();
      case 'usuarios':
        return const UsuariosScreen();
      default:
        return InicioScreen(modulos: modulosVisiveis(), aoAbrir: _selecionar);
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
                _BarraLateral(selecionado: selecionado, alertas: alertas, aoSelecionar: _selecionar),
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
            alertas: alertas,
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
              alertas: alertas?.total ?? 0, // no celular o menu fica fechado: o selo vai no botao dele
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
  final int alertas; // total de alertas, aparece como selo no botao do menu
  const BarraTopo({super.key, this.aoAbrirMenu, this.alertas = 0});

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
                    icon: Badge(
                      isLabelVisible: alertas > 0,
                      label: Text('$alertas'),
                      child: Icon(Icons.menu, color: corIcone),
                    ),
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
  final String selecionado;
  final ResumoAlertas? alertas;
  final ValueChanged<String> aoSelecionar;
  const _BarraLateral({required this.selecionado, this.alertas, required this.aoSelecionar});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: Theme.of(context).colorScheme.surface,
      child: _ListaModulos(selecionado: selecionado, alertas: alertas, aoSelecionar: aoSelecionar),
    );
  }
}

// lista de modulos usada tanto na lateral quanto no drawer
class _ListaModulos extends StatelessWidget {
  final String selecionado;
  final ResumoAlertas? alertas;
  final ValueChanged<String> aoSelecionar;
  const _ListaModulos({required this.selecionado, this.alertas, required this.aoSelecionar});

  // selo com o total no item Alertas (vermelho se tem alerta de prioridade alta)
  // e com os locais com problema no item Armazenamento
  Widget? _selo(ItemNav m) {
    final a = alertas;
    if (a == null) return null;
    if (m.id == 'armazenamento' && a.temperatura > 0) {
      return Tooltip(
        message: '${a.temperatura} local(is) com problema de temperatura',
        child: Badge(label: Text('${a.temperatura}'), backgroundColor: Colors.red),
      );
    }
    if (m.id != 'alertas' || a.total == 0) return null;
    return Tooltip(
      message: a.descricao,
      child: Badge(
        label: Text('${a.total}'),
        backgroundColor: a.prioridadeAlta > 0 ? Colors.red : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modulos = modulosVisiveis();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: modulos.length,
      itemBuilder: (_, i) {
        final m = modulos[i];
        final sel = m.id == selecionado;
        return ListTile(
          leading: Icon(m.icone, color: sel ? corAzul : null),
          title: Text(
            m.titulo,
            style: TextStyle(
              color: sel ? corAzul : null,
              fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          trailing: _selo(m),
          selected: sel,
          selectedTileColor: corAzul.withValues(alpha: 0.10),
          onTap: () => aoSelecionar(m.id),
        );
      },
    );
  }
}
