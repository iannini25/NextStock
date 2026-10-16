import 'package:flutter/material.dart';
import '../models/lote.dart';
import '../models/produto.dart';
import '../services/api_service.dart';
import 'lote_form.dart';
import 'movimentacoes_screen.dart';

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

  Widget selo(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(10)),
      child: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
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
            title: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${l.titulo}  •  ${l.quantidadeAtual} de ${l.quantidadeInicial} ${l.unidade ?? ""}'),
                // o proximo lote a sair numa venda (vence primeiro e ainda esta bom)
                if (l.venderPrimeiro) selo('VENDER PRIMEIRO', Colors.green),
                // vencido e pra tirar da prateleira, nao pra vender
                if (l.vencido && !l.esgotado) selo('RETIRAR', Colors.red),
              ],
            ),
            subtitle: Text(
              '${l.esgotado ? "ESGOTADO" : l.textoValidade}${l.dataValidade != null ? " (${l.dataValidade})" : ""}'
              '${l.posicaoSaida != null ? "  •  ${l.posicaoSaida}º na fila de saída" : ""}\n'
              'entrada: ${l.dataEntrada ?? "-"}  •  ${l.nomeOrigem}  •  custo: $custo',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Histórico do lote',
                  icon: const Icon(Icons.history),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MovimentacoesScreen(idLote: l.id, titulo: 'Histórico — ${l.titulo}'),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Corrigir código ou validade',
                  icon: const Icon(Icons.edit),
                  onPressed: () => abrirForm(l),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
