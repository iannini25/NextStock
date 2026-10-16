import 'package:flutter/material.dart';
import '../models/movimentacao.dart';
import '../models/produto.dart';
import '../services/api_service.dart';

// historico de tudo que entrou e saiu do estoque. com idLote, mostra so o historico daquele lote
class MovimentacoesScreen extends StatefulWidget {
  final int? idLote;
  final String? titulo;
  const MovimentacoesScreen({super.key, this.idLote, this.titulo});

  @override
  State<MovimentacoesScreen> createState() => _MovimentacoesScreenState();
}

class _MovimentacoesScreenState extends State<MovimentacoesScreen> {
  // filtros
  int? produtoId;
  String? tipo;
  int? periodoDias = 30; // null = todo o periodo

  List<Movimentacao> itens = [];
  int total = 0;
  int pagina = 1;
  bool carregando = true;
  bool carregandoMais = false;
  List<Produto> produtos = [];
  Map<String, String> tipos = const {
    'entrada': 'Entrada',
    'saldo_inicial': 'Saldo inicial',
    'venda': 'Venda',
    'ajuste_entrada': 'Ajuste (entrada)',
    'ajuste_saida': 'Ajuste (saída)',
    'perda': 'Perda',
    'descarte': 'Descarte',
  };

  bool get doLote => widget.idLote != null;

  @override
  void initState() {
    super.initState();
    carregar();
    if (!doLote) carregarProdutos();
  }

  // so serve pro filtro de produto: se falhar, o historico continua funcionando
  Future<void> carregarProdutos() async {
    try {
      final lista = await ApiService.listarProdutos();
      if (!mounted) return;
      setState(() => produtos = lista);
    } catch (_) {}
  }

  String? inicioDoPeriodo() {
    if (periodoDias == null) return null;
    final d = DateTime.now().subtract(Duration(days: periodoDias!));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<ResultadoMovimentacoes> buscar(int p) {
    return ApiService.listarMovimentacoes(
      idProduto: doLote ? null : produtoId,
      idLote: widget.idLote,
      tipo: tipo,
      inicio: doLote ? null : inicioDoPeriodo(),
      pagina: p,
    );
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final r = await buscar(1);
      if (!mounted) return;
      setState(() {
        itens = r.itens;
        total = r.total;
        pagina = 1;
        if (r.tipos.isNotEmpty) tipos = r.tipos;
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => carregando = false);
      mostrarErro(e);
    }
  }

  Future<void> carregarMais() async {
    setState(() => carregandoMais = true);
    try {
      final r = await buscar(pagina + 1);
      if (!mounted) return;
      setState(() {
        itens = [...itens, ...r.itens];
        total = r.total;
        pagina = r.pagina;
      });
    } catch (e) {
      mostrarErro(e);
    }
    if (mounted) setState(() => carregandoMais = false);
  }

  void mostrarErro(Object e) {
    if (!mounted) return;
    final msg = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo ?? 'Movimentações'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: carregar)],
      ),
      body: Column(
        children: [
          montarFiltros(),
          Expanded(child: montarLista()),
        ],
      ),
    );
  }

  Widget montarFiltros() {
    final produtoValido = produtos.any((p) => p.id == produtoId) ? produtoId : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (!doLote)
            DropdownButton<int?>(
              value: produtoValido,
              hint: const Text('Todos os produtos'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Todos os produtos')),
                ...produtos.map((p) => DropdownMenuItem<int?>(value: p.id, child: Text(p.nome))),
              ],
              onChanged: (v) {
                setState(() => produtoId = v);
                carregar();
              },
            ),
          DropdownButton<String?>(
            value: tipo,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Todos os tipos')),
              ...tipos.entries.map((t) => DropdownMenuItem<String?>(value: t.key, child: Text(t.value))),
            ],
            onChanged: (v) {
              setState(() => tipo = v);
              carregar();
            },
          ),
          if (!doLote)
            DropdownButton<int?>(
              value: periodoDias,
              items: const [
                DropdownMenuItem<int?>(value: 7, child: Text('Últimos 7 dias')),
                DropdownMenuItem<int?>(value: 30, child: Text('Últimos 30 dias')),
                DropdownMenuItem<int?>(value: 90, child: Text('Últimos 90 dias')),
                DropdownMenuItem<int?>(value: null, child: Text('Todo o período')),
              ],
              onChanged: (v) {
                setState(() => periodoDias = v);
                carregar();
              },
            ),
        ],
      ),
    );
  }

  Widget montarLista() {
    if (carregando) return const Center(child: CircularProgressIndicator());
    if (itens.isEmpty) return const Center(child: Text('Nenhuma movimentação nesse filtro.'));
    final faltam = total - itens.length;
    return ListView.builder(
      itemCount: itens.length + 1,
      itemBuilder: (_, i) {
        if (i == itens.length) {
          if (faltam <= 0) return const SizedBox(height: 16);
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: TextButton(
                onPressed: carregandoMais ? null : carregarMais,
                child: Text(carregandoMais ? 'Carregando...' : 'Carregar mais ($faltam restantes)'),
              ),
            ),
          );
        }
        return montarItem(itens[i]);
      },
    );
  }

  Widget montarItem(Movimentacao m) {
    final cor = m.entrou ? Colors.green : Colors.red;
    final detalhes = [
      m.nomeTipo,
      if (m.lote != null) m.lote!,
      if (m.saldoProdutoApos != null) 'saldo: ${m.saldoProdutoApos}',
    ].join('  •  ');
    final quem = [
      m.quando,
      m.nomeOrigem,
      if (m.usuario != null) 'por ${m.usuario}',
    ].join('  •  ');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(m.entrou ? Icons.add_circle : Icons.remove_circle, color: cor),
        title: Text('${m.quantidadeComSinal} ${m.unidade ?? ""}  •  ${m.produtoNome ?? ""}'),
        subtitle: Text([detalhes, quem, if (m.observacao != null) m.observacao!].join('\n')),
        isThreeLine: true,
      ),
    );
  }
}
