import 'package:flutter/material.dart';
import '../models/lote.dart';
import '../models/produto.dart';
import '../services/api_service.dart';
import 'lote_form.dart';

// lotes de um produto: o que tem em estoque, separado por entrada, validade e custo
class LotesScreen extends StatefulWidget {
  final Produto produto;
  const LotesScreen({super.key, required this.produto});

  @override
  State<LotesScreen> createState() => _LotesScreenState();
}

class _LotesScreenState extends State<LotesScreen> {
  late Produto produto = widget.produto;
  List<Lote> lotes = [];
  bool mostrarEsgotados = false;
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final r = await ApiService.listarLotes(widget.produto.id!, todos: mostrarEsgotados);
      if (!mounted) return;
      setState(() {
        produto = r.produto;
        lotes = r.lotes;
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

  Future<void> abrirForm([Lote? lote]) async {
    final salvou = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoteForm(produto: produto, lote: lote)),
    );
    if (salvou == true) carregar();
  }

  Color corValidade(Lote l) {
    final d = l.diasParaVencer;
    if (l.esgotado) return Colors.grey;
    if (d == null) return Colors.blueGrey;
    if (d < 0) return Colors.red;
    if (d <= 3) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lotes — ${produto.nome}'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: carregar)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrirForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nova entrada'),
      ),
      body: Column(
        children: [
          ListTile(
            title: Text(
              'Estoque: ${produto.quantidade ?? 0} ${produto.unidade ?? ""}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('próxima validade: ${produto.validade ?? "-"}  •  a venda sai primeiro do lote que vence antes'),
          ),
          SwitchListTile(
            title: const Text('Mostrar lotes esgotados'),
            value: mostrarEsgotados,
            onChanged: (v) {
              setState(() => mostrarEsgotados = v);
              carregar();
            },
          ),
          Expanded(child: montarLista()),
        ],
      ),
    );
  }

  Widget montarLista() {
    if (carregando) return const Center(child: CircularProgressIndicator());
    if (lotes.isEmpty) return const Center(child: Text('Nenhum lote com estoque. Use "Nova entrada".'));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80), // espaco pro botao
      itemCount: lotes.length,
      itemBuilder: (_, i) {
        final l = lotes[i];
        final custo = l.custoUnitario == null ? '-' : 'R\$ ${l.custoUnitario!.toStringAsFixed(2)}';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: Icon(Icons.inventory, color: corValidade(l)),
            title: Text('${l.titulo}  •  ${l.quantidadeAtual} de ${l.quantidadeInicial} ${l.unidade ?? ""}'),
            subtitle: Text(
              '${l.esgotado ? "ESGOTADO" : l.textoValidade}${l.dataValidade != null ? " (${l.dataValidade})" : ""}\n'
              'entrada: ${l.dataEntrada ?? "-"}  •  ${l.nomeOrigem}  •  custo: $custo',
            ),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: 'Corrigir código ou validade',
              icon: const Icon(Icons.edit),
              onPressed: () => abrirForm(l),
            ),
          ),
        );
      },
    );
  }
}
