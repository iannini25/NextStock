import 'package:flutter/material.dart';
import '../models/reposicao.dart';
import '../services/api_service.dart';

class ReposicaoScreen extends StatefulWidget {
  const ReposicaoScreen({super.key});

  @override
  State<ReposicaoScreen> createState() => _ReposicaoScreenState();
}

class _ReposicaoScreenState extends State<ReposicaoScreen> {
  List<Reposicao> lista = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final r = await ApiService.listarReposicao();
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

  Color corUrgencia(String urgencia) {
    if (urgencia == 'alta') return Colors.red;
    if (urgencia == 'media') return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reposição'),
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
      return const Center(child: Text('Nenhuma reposição sugerida.'));
    }
    return ListView.builder(
      itemCount: lista.length,
      itemBuilder: (_, i) {
        final r = lista[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: Icon(Icons.autorenew, color: corUrgencia(r.urgencia)),
            title: Text(r.produtoNome),
            subtitle: Text(
              'repor: ${r.quantidadeIdeal} ${r.unidade ?? ""}  •  prazo: ${r.prazoIdeal}  •  '
              'estoque: ${r.estoqueAtual} (mín: ${r.estoqueMinimo})  •  '
              'média: ${r.mediaDiaria.toStringAsFixed(1)}/dia',
            ),
            trailing: Text(r.urgencia),
          ),
        );
      },
    );
  }
}
