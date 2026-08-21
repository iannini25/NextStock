import 'package:flutter/material.dart';
import '../models/produto.dart';
import '../models/venda.dart';
import '../services/api_service.dart';

class VendaForm extends StatefulWidget {
  const VendaForm({super.key});

  @override
  State<VendaForm> createState() => _VendaFormState();
}

class _VendaFormState extends State<VendaForm> {
  final quantidade = TextEditingController();
  final data = TextEditingController();

  List<Produto> produtos = [];
  int? produtoId;
  bool carregouProdutos = false;
  bool salvando = false;

  @override
  void initState() {
    super.initState();
    carregarProdutos();
  }

  Future<void> carregarProdutos() async {
    try {
      final lista = await ApiService.listarProdutos();
      if (!mounted) return;
      setState(() {
        produtos = lista;
        carregouProdutos = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => carregouProdutos = true);
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

  Future<void> salvar() async {
    if (produtoId == null) {
      mostrarErro(Exception('escolha o produto'));
      return;
    }
    setState(() => salvando = true);
    final v = Venda(
      idProduto: produtoId!,
      quantidade: int.tryParse(quantidade.text) ?? 0,
      dataVenda: data.text.isEmpty ? null : data.text,
    );
    try {
      await ApiService.registrarVenda(v);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Nova venda')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          montarDropdown(),
          campo(quantidade, 'Quantidade *', numero: true),
          campo(data, 'Data (aaaa-mm-dd, vazio = hoje)'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: salvando ? null : salvar,
            child: Text(salvando ? 'Salvando...' : 'Registrar venda'),
          ),
        ],
      ),
    );
  }

  Widget montarDropdown() {
    if (!carregouProdutos) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: LinearProgressIndicator(),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int?>(
        initialValue: produtoId,
        decoration: const InputDecoration(
            labelText: 'Produto *', border: OutlineInputBorder()),
        items: produtos
            .map((p) => DropdownMenuItem<int?>(
                value: p.id,
                child: Text('${p.nome} (estoque: ${p.quantidade ?? 0})')))
            .toList(),
        onChanged: (v) => produtoId = v,
      ),
    );
  }

  Widget campo(TextEditingController c, String label, {bool numero = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: numero ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
