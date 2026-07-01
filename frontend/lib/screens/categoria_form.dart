import 'package:flutter/material.dart';
import '../models/categoria.dart';
import '../services/api_service.dart';

class CategoriaForm extends StatefulWidget {
  final Categoria? categoria;
  const CategoriaForm({super.key, this.categoria});

  @override
  State<CategoriaForm> createState() => _CategoriaFormState();
}

class _CategoriaFormState extends State<CategoriaForm> {
  final nome = TextEditingController();
  final descricao = TextEditingController();
  bool salvando = false;

  @override
  void initState() {
    super.initState();
    final c = widget.categoria;
    if (c != null) {
      nome.text = c.nome;
      descricao.text = c.descricao ?? '';
    }
  }

  void mostrarErro(Object e) {
    if (!mounted) return;
    final msg = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> salvar() async {
    setState(() => salvando = true);
    final c = Categoria(
      nome: nome.text,
      descricao: descricao.text.isEmpty ? null : descricao.text,
    );
    try {
      if (widget.categoria == null) {
        await ApiService.criarCategoria(c);
      } else {
        await ApiService.atualizarCategoria(widget.categoria!.id!, c);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => salvando = false);
      mostrarErro(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.categoria != null;
    return Scaffold(
      appBar: AppBar(title: Text(editando ? 'Editar categoria' : 'Nova categoria')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: nome,
              decoration: const InputDecoration(
                  labelText: 'Nome *', border: OutlineInputBorder()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: descricao,
              decoration: const InputDecoration(
                  labelText: 'Descrição', border: OutlineInputBorder()),
            ),
          ),
          ElevatedButton(
            onPressed: salvando ? null : salvar,
            child: Text(salvando ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}
