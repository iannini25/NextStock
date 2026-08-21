import 'package:flutter/material.dart';
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
      return const Center(child: Text('Nenhuma recomendação no momento.'));
    }
    return ListView.builder(
      itemCount: lista.length,
      itemBuilder: (_, i) {
        final r = lista[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: Icon(Icons.lightbulb, color: corPrioridade(r.prioridade)),
            title: Text(r.produtoNome),
            subtitle: Text(r.mensagem),
            trailing: Text(r.prioridade),
          ),
        );
      },
    );
  }
}
