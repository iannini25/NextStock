import 'dart:async';

import 'package:flutter/material.dart';
import '../models/previa_venda.dart';
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

  // previa: de quais lotes a venda vai sair (o que vence antes sai primeiro)
  PreviaVenda? previa;
  Timer? esperaPrevia;
  int pedidoPrevia = 0; // so a resposta do ultimo pedido vale

  @override
  void initState() {
    super.initState();
    carregarProdutos();
  }

  @override
  void dispose() {
    esperaPrevia?.cancel();
    quantidade.dispose();
    data.dispose();
    super.dispose();
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

  // espera a pessoa parar de digitar e pergunta pra API de quais lotes a venda vai sair.
  // se der erro, so nao mostra a previa: a venda continua podendo ser registrada
  void atualizarPrevia() {
    esperaPrevia?.cancel();
    final pedido = ++pedidoPrevia; // invalida também pedidos em andamento ao limpar o campo
    setState(() => previa = null);
    final id = produtoId;
    final qtd = int.tryParse(quantidade.text.trim());
    if (id == null || qtd == null || qtd <= 0) return;
    esperaPrevia = Timer(const Duration(milliseconds: 400), () async {
      try {
        final p = await ApiService.previaVenda(id, qtd);
        if (!mounted || pedido != pedidoPrevia) return;
        setState(() => previa = p);
      } catch (_) {
        if (!mounted || pedido != pedidoPrevia) return;
        setState(() => previa = null);
      }
    });
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
      final consumidos = await ApiService.registrarVenda(v);
      if (!mounted) return;
      if (consumidos.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Venda registrada: saiu ${consumidos.map((s) => s.texto).join(' e ')}'),
        ));
      }
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
          campo(quantidade, 'Quantidade *', numero: true, aoMudar: (_) => atualizarPrevia()),
          campo(data, 'Data (aaaa-mm-dd, vazio = hoje)'),
          if (previa != null) montarPrevia(previa!),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: salvando ? null : salvar,
            child: Text(salvando ? 'Salvando...' : 'Registrar venda'),
          ),
        ],
      ),
    );
  }

  Widget montarPrevia(PreviaVenda p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vai sair (o que vence antes sai primeiro):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            for (final s in p.lotes)
              Text('• ${s.texto}', style: TextStyle(color: s.vencido ? Colors.red : null)),
            if (!p.suficiente)
              Text('Estoque insuficiente: faltam ${p.falta}', style: const TextStyle(color: Colors.red)),
            if (p.aviso != null) Text(p.aviso!, style: const TextStyle(color: Colors.orange)),
          ],
        ),
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
        onChanged: (v) {
          produtoId = v;
          atualizarPrevia();
        },
      ),
    );
  }

  Widget campo(TextEditingController c, String label, {bool numero = false, ValueChanged<String>? aoMudar}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        onChanged: aoMudar,
        keyboardType: numero ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
