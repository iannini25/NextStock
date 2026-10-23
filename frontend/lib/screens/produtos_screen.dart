import 'dart:async';

import 'package:flutter/material.dart';
import '../models/categoria.dart';
import '../models/produto.dart';
import '../services/api_service.dart';
import '../services/sessao.dart';
import 'produto_form.dart';
import 'lotes_screen.dart';

// filtros de situacao (valor que vai pra API -> texto do chip)
const Map<String, String> situacoesFiltro = {
  'baixo_estoque': 'Baixo estoque',
  'sem_estoque': 'Sem estoque',
  'vencendo': 'Vence em até 7 dias',
  'vencido': 'Vencidos',
};

class ProdutosScreen extends StatefulWidget {
  const ProdutosScreen({super.key});

  @override
  State<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends State<ProdutosScreen> {
  List<Produto> produtos = [];
  List<Categoria> categorias = [];
  bool carregando = true;

  // filtros
  final busca = TextEditingController();
  int? categoriaId;
  String? situacao;
  Timer? esperaDigitacao;
  int pedidoAtual = 0; // so a resposta do ultimo pedido vale (evita lista velha chegando depois)

  bool get temFiltro => busca.text.trim().isNotEmpty || categoriaId != null || situacao != null;

  @override
  void initState() {
    super.initState();
    carregar();
    carregarCategorias();
  }

  @override
  void dispose() {
    esperaDigitacao?.cancel();
    busca.dispose();
    super.dispose();
  }

  Future<void> carregar() async {
    final pedido = ++pedidoAtual;
    setState(() => carregando = true);
    try {
      final lista = await ApiService.listarProdutos(
        busca: busca.text,
        idCategoria: categoriaId,
        situacao: situacao,
      );
      if (!mounted || pedido != pedidoAtual) return;
      setState(() {
        produtos = lista;
        carregando = false;
      });
    } catch (e) {
      if (!mounted || pedido != pedidoAtual) return;
      setState(() => carregando = false);
      mostrarErro(e);
    }
  }

  // as categorias so servem pro filtro: se falhar, a lista de produtos continua funcionando
  Future<void> carregarCategorias() async {
    try {
      final lista = await ApiService.listarCategorias();
      if (!mounted) return;
      setState(() => categorias = lista);
    } catch (_) {}
  }

  // espera a pessoa parar de digitar um pouco antes de buscar
  void digitou(String _) {
    esperaDigitacao?.cancel();
    esperaDigitacao = Timer(const Duration(milliseconds: 400), carregar);
    setState(() {}); // atualiza o botao de limpar
  }

  void limparFiltros() {
    esperaDigitacao?.cancel();
    busca.clear();
    setState(() {
      categoriaId = null;
      situacao = null;
    });
    carregar();
  }

  void mostrarErro(Object e) {
    if (!mounted) return;
    final msg = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // abre o formulario; se passar um produto e edicao
  Future<void> abrirForm([Produto? p]) async {
    final salvou = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProdutoForm(produto: p)),
    );
    if (salvou == true) carregar();
  }

  // entradas e correcoes nos lotes mudam o estoque: recarrega sempre na volta
  Future<void> abrirLotes(Produto p) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => LotesScreen(produto: p)));
    if (mounted) carregar();
  }

  Future<void> excluir(Produto p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text('Excluir o produto "${p.nome}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sim')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deletarProduto(p.id!);
      carregar();
    } catch (e) {
      mostrarErro(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produtos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => abrirForm(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          montarFiltros(),
          Expanded(child: montarCorpo()),
        ],
      ),
    );
  }

  Widget montarFiltros() {
    // se a categoria escolhida sumiu da lista, fica "todas"
    final categoriaValida = categorias.any((c) => c.id == categoriaId) ? categoriaId : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: busca,
            onChanged: digitou,
            decoration: InputDecoration(
              labelText: 'Buscar por nome ou código de barras',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: busca.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        busca.clear();
                        digitou('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<int?>(
                value: categoriaValida,
                hint: const Text('Todas as categorias'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Todas as categorias')),
                  ...categorias.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.nome))),
                ],
                onChanged: (v) {
                  setState(() => categoriaId = v);
                  carregar();
                },
              ),
              for (final s in situacoesFiltro.entries)
                ChoiceChip(
                  label: Text(s.value),
                  selected: situacao == s.key,
                  onSelected: (marcado) {
                    setState(() => situacao = marcado ? s.key : null);
                    carregar();
                  },
                ),
              if (temFiltro)
                TextButton.icon(
                  onPressed: limparFiltros,
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Limpar filtros'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget montarCorpo() {
    if (carregando) return const Center(child: CircularProgressIndicator());
    if (produtos.isEmpty) {
      return Center(
        child: Text(temFiltro ? 'Nenhum produto encontrado com esses filtros.' : 'Nenhum produto cadastrado.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80), // espaco pro botao
      itemCount: produtos.length,
      itemBuilder: (_, i) {
        final p = produtos[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(p.nome),
            subtitle: Text(
              '${p.categoriaNome ?? "sem categoria"}  •  R\$ ${p.precoVenda?.toStringAsFixed(2) ?? "-"}\n'
              'estoque: ${p.quantidade ?? 0} ${p.unidade ?? ""} (mín: ${p.estoqueMinimo ?? 0})  •  validade: ${p.validade ?? "-"}',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(tooltip: 'Editar', icon: const Icon(Icons.edit), onPressed: () => abrirForm(p)),
                IconButton(tooltip: 'Lotes', icon: const Icon(Icons.inventory), onPressed: () => abrirLotes(p)),
                if (Sessao.ehAdmin) // so admin exclui
                  IconButton(
                      tooltip: 'Excluir',
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => excluir(p)),
              ],
            ),
          ),
        );
      },
    );
  }
}
