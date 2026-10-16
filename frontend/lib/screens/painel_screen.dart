import 'package:flutter/material.dart';
import '../models/painel.dart';
import '../services/api_service.dart';

class PainelScreen extends StatefulWidget {
  const PainelScreen({super.key});

  @override
  State<PainelScreen> createState() => _PainelScreenState();
}

class _PainelScreenState extends State<PainelScreen> {
  Painel? painel;
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final r = await ApiService.montarPainel();
      if (!mounted) return;
      setState(() {
        painel = r;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel gerencial'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: carregar),
        ],
      ),
      body: montarCorpo(),
    );
  }

  Widget montarCorpo() {
    if (carregando) return const Center(child: CircularProgressIndicator());
    if (painel == null) return const Center(child: Text('Não foi possível carregar o painel.'));
    final p = painel!;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        montarIndicador('Produtos cadastrados', '${p.totalProdutos}'),
        montarIndicador('Itens em estoque', '${p.itensEmEstoque}'),
        montarIndicador('Valor em estoque', 'R\$ ${p.valorEstoque.toStringAsFixed(2)}'),
        montarIndicador('Produtos vencidos', '${p.produtosVencidos}',
            cor: p.produtosVencidos > 0 ? Colors.red : null),
        montarIndicador('Valor perdido com vencidos', 'R\$ ${p.valorVencido.toStringAsFixed(2)}',
            cor: p.valorVencido > 0 ? Colors.red : null),
        montarIndicador('Vencendo em 7 dias', '${p.produtosVencendo}',
            cor: p.produtosVencendo > 0 ? Colors.red : null),
        montarIndicador('Em risco de faltar', '${p.produtosEmRisco}',
            cor: p.produtosEmRisco > 0 ? Colors.red : null),
        montarIndicador('Vendas em 30 dias', '${p.vendas30Dias}'),
        montarIndicador('Faturamento em 30 dias', 'R\$ ${p.faturamento30Dias.toStringAsFixed(2)}'),
        montarIndicador('Desperdício', '${p.percentualDesperdicio.toStringAsFixed(2)}%'),
        montarIndicador('Giro de estoque', p.giroEstoque.toStringAsFixed(2)),
        // perdas e descartes registrados: o prejuizo fica no historico mesmo depois de jogar o produto fora
        montarIndicador('Perdas registradas (30 dias)', 'R\$ ${p.valorPerdas30Dias.toStringAsFixed(2)}',
            cor: p.valorPerdas30Dias > 0 ? Colors.red : null),
        montarIndicador('Itens perdidos (30 dias)', '${p.quantidadePerdas30Dias}'),
      ],
    );
  }

  Widget montarIndicador(String nome, String valor, {Color? cor}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(nome),
        trailing: Text(
          valor,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cor),
        ),
      ),
    );
  }
}
