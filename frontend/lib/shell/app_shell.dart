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
import '../screens/importar_erp_screen.dart';
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
  final String secao; // grupo do menu (aparece como titulo pequeno em cima do grupo)
  const ItemNav(this.id, this.icone, this.titulo, {this.soAdmin = false, this.secao = ''});
}

// os itens ficam em grupos pra achar mais facil no menu
const List<ItemNav> modulosNav = [
  ItemNav('inicio', Icons.home, 'Início', secao: 'Principal'),
  ItemNav('alertas', Icons.notifications, 'Alertas', secao: 'Principal'),
  ItemNav('assistente', Icons.smart_toy, 'Assistente', secao: 'Principal'),
  ItemNav('produtos', Icons.inventory_2, 'Produtos', secao: 'Estoque'),
  ItemNav('categorias', Icons.category, 'Categorias', secao: 'Estoque'),
  ItemNav('movimentacoes', Icons.swap_vert, 'Movimentações', secao: 'Estoque'),
  ItemNav('perdas', Icons.delete_sweep, 'Perdas', secao: 'Estoque'),
  ItemNav('armazenamento', Icons.thermostat, 'Armazenamento', secao: 'Estoque'),
  ItemNav('vendas', Icons.point_of_sale, 'Vendas', secao: 'Vendas e planejamento'),
  ItemNav('eventos', Icons.event, 'Eventos', secao: 'Vendas e planejamento'),
  ItemNav('previsao', Icons.trending_up, 'Previsão', secao: 'Vendas e planejamento'),
  ItemNav('compras', Icons.shopping_cart, 'Compras', secao: 'Vendas e planejamento'),
  ItemNav('reposicao', Icons.autorenew, 'Reposição', secao: 'Vendas e planejamento'),
  ItemNav('painel', Icons.dashboard, 'Painel', secao: 'Análises'),
  ItemNav('recomendacoes', Icons.lightbulb, 'Recomendações', secao: 'Análises'),
  ItemNav('relatorios', Icons.bar_chart, 'Relatórios', secao: 'Análises'),
  ItemNav('importar', Icons.cloud_upload, 'Importar', soAdmin: true, secao: 'Configurações'),
  ItemNav('erp', Icons.hub, 'Integração ERP', soAdmin: true, secao: 'Configurações'),
  ItemNav('empresa', Icons.business, 'Empresa', secao: 'Configurações'),
  ItemNav('usuarios', Icons.people, 'Usuários', soAdmin: true, secao: 'Configurações'),
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
      case 'importar':
        return const ImportarErpScreen();
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
          const Divider(height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BarraLateral(selecionado: selecionado, alertas: alertas, aoSelecionar: _selecionar),
                const VerticalDivider(width: 1),
                // em tela grande a tela do modulo fica no meio, com largura maxima
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: _corpo(),
                    ),
                  ),
                ),
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
      // mesma cor do menu lateral do computador
      drawer: Drawer(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF12203A) : Colors.white,
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
          const Divider(height: 1),
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

  // botao com a inicial do usuario. clicando abre um menuzinho com o nome, o perfil e o Sair
  Widget _usuario(BuildContext context, Usuario usuario, Color corTexto) {
    final inicial = usuario.nome.trim().isEmpty ? '?' : usuario.nome.trim()[0].toUpperCase();
    // no celular so a bolinha, pra caber na barra
    final mostrarNome = aoAbrirMenu == null;
    return PopupMenuButton<String>(
      tooltip: 'Conta',
      offset: const Offset(0, 48),
      onSelected: (opcao) {
        if (opcao == 'sair') Sessao.sair();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                usuario.nome,
                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
              ),
              Text(usuario.nomePerfil, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'sair',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20),
              SizedBox(width: 12),
              Text('Sair'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: corAzul,
              child: Text(
                inicial,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            if (mostrarNome) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  usuario.nome,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: corTexto, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.expand_more, color: corTexto),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    // mesma cor do menu lateral: branco no claro, azul escuro no escuro
    final corBarra = escuro ? const Color(0xFF12203A) : Colors.white;
    final corIcone = escuro ? Colors.white : corNavy;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      color: corBarra,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
            // marca no canto esquerdo; tema e usuario no canto direito
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
                  const SizedBox(width: 20),
                _marca(escuro, 'assets/logo.png', 36),
                const SizedBox(width: 10),
                _marca(escuro, 'assets/nome.png', 26),
                const Spacer(),
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
                ValueListenableBuilder<Usuario?>(
                  valueListenable: Sessao.usuario,
                  builder: (_, usuario, _) {
                    if (usuario == null) return const SizedBox.shrink();
                    return _usuario(context, usuario, corIcone);
                  },
                ),
                const SizedBox(width: 12),
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
    // mesma familia de cor da barra de cima: branco no claro, azul escuro no escuro
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 240,
      color: escuro ? const Color(0xFF12203A) : Colors.white,
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
        // mostra o nome do grupo antes do primeiro item de cada grupo
        final comecaSecao = i == 0 || modulos[i - 1].secao != m.secao;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (comecaSecao)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 6),
                child: Text(
                  m.secao.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            // espaco dos lados pro fundo do item selecionado ficar arredondado
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: ListTile(
                dense: true,
                leading: Icon(m.icone, color: sel ? corAzul : null),
                title: Text(
                  m.titulo,
                  style: TextStyle(
                    fontSize: 14,
                    color: sel ? corAzul : null,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: _selo(m),
                selected: sel,
                selectedTileColor: corAzul.withValues(alpha: 0.12),
                onTap: () => aoSelecionar(m.id),
              ),
            ),
          ],
        );
      },
    );
  }
}
