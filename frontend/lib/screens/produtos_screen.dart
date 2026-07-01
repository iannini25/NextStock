import 'package:flutter/material.dart';
import '../models/produto.dart';
import '../services/api_service.dart';
import 'produto_form.dart';

class ProdutosScreen extends StatefulWidget {
  const ProdutosScreen({super.key});

  @override
  State<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends State<ProdutosScreen> {
  List<Produto> produtos = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final lista = await ApiService.listarProdutos();
      if (!mounted) return;
      setState(() {
        produtos = lista;
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => carregando = false);
      mostrarErro(e);
    }
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
      appBar: AppBar(title: const Text('NextStock')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => abrirForm(),
        child: const Icon(Icons.add),
      ),
      body: montarCorpo(),
    );
  }

  Widget montarCorpo() {
    if (carregando) return const Center(child: CircularProgressIndicator());
    if (produtos.isEmpty) return const Center(child: Text('Nenhum produto cadastrado.'));
    return ListView.builder(
      itemCount: produtos.length,
      itemBuilder: (_, i) {
        final p = produtos[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(p.nome),
            subtitle: Text(
              '${p.categoriaNome ?? "sem categoria"}  •  R\$ ${p.precoVenda?.toStringAsFixed(2) ?? "-"}\n'
              'estoque: ${p.quantidade ?? 0} ${p.unidade ?? ""}  •  validade: ${p.validade ?? "-"}',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit), onPressed: () => abrirForm(p)),
                IconButton(
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
