import 'package:flutter/material.dart';
import '../models/alerta.dart';
import '../models/recomendacao.dart';
import '../services/api_service.dart';

class RecomendacoesScreen extends StatefulWidget {
  const RecomendacoesScreen({super.key});

  @override
  State<RecomendacoesScreen> createState() => _RecomendacoesScreenState();
}

class _RecomendacoesScreenState extends State<RecomendacoesScreen> {
  List<Recomendacao> lista = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final r = await ApiService.listarRecomendacoes();
      if (!mounted) return;
      setState(() {
        lista = r;
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

  Color corPrioridade(String prioridade) {
    if (prioridade == 'alta') return Colors.red;
    if (prioridade == 'media') return Colors.orange;
    return Colors.green;
  }

  // selo colorido com a prioridade (igual ao da tela de alertas)
  Widget selo(String nivel, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        border: Border.all(color: cor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        nomesPrioridade[nivel] ?? nivel,
        style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recomendações'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: carregar),
        ],
      ),
      body: montarLista(),
    );
  }

  Widget montarLista() {
    if (carregando) return const Center(child: CircularProgressIndicator());
    if (lista.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lightbulb_outline, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Nenhuma recomendação no momento.'),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: lista.length,
      itemBuilder: (_, i) {
        final r = lista[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            // recomendacao de um lote especifico (validade) ganha o icone de lote
            leading: Icon(r.idLote != null ? Icons.inventory : Icons.lightbulb, color: corPrioridade(r.prioridade)),
            title: Text(r.produtoNome),
            subtitle: Text(r.mensagem),
            trailing: selo(r.prioridade, corPrioridade(r.prioridade)),
          ),
        );
      },
    );
  }
}
