import 'package:flutter/material.dart';
import '../models/categoria.dart';
import '../services/api_service.dart';
import 'categoria_form.dart';

class CategoriasScreen extends StatefulWidget {
  const CategoriasScreen({super.key});

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  List<Categoria> categorias = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final lista = await ApiService.listarCategorias();
      if (!mounted) return;
      setState(() {
        categorias = lista;
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

  Future<void> abrirForm([Categoria? c]) async {
    final salvou = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CategoriaForm(categoria: c)),
    );
    if (salvou == true) carregar();
  }

  Future<void> excluir(Categoria c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text('Excluir a categoria "${c.nome}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sim')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deletarCategoria(c.id!);
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
    if (categorias.isEmpty) {
      return const Center(child: Text('Nenhuma categoria cadastrada.'));
    }
    return ListView.builder(
      itemCount: categorias.length,
      itemBuilder: (_, i) {
        final c = categorias[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(c.nome),
            subtitle: Text(c.descricao ?? '-'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit), onPressed: () => abrirForm(c)),
                IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => excluir(c)),
              ],
            ),
          ),
        );
      },
    );
  }
}
