import 'package:flutter/material.dart';
import '../main.dart';
import '../models/produto.dart';
import '../services/api_service.dart';

// Tela dos alertas. Tem dois modos: o que ta vencendo e o que ta acabando.
class AlertasScreen extends StatefulWidget {
  const AlertasScreen({super.key});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  bool modoVencimento = true; // false = risco de ruptura
  int dias = 7;
  List<Produto> lista = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final r = modoVencimento
          ? await ApiService.listarProdutosVencendo(dias)
          : await ApiService.listarProdutosEmRisco();
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

  void trocarModo(bool vencimento) {
    setState(() => modoVencimento = vencimento);
    carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: carregar),
        ],
      ),
      body: Column(
        children: [
          montarBotoes(),
          if (modoVencimento) montarFiltroDias(),
          Expanded(child: montarLista()),
        ],
      ),
    );
  }

  // os dois botoes que trocam o tipo de alerta
  Widget montarBotoes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => trocarModo(true),
              icon: const Icon(Icons.event_busy, size: 18),
              label: const Text('Vencendo'),
              style: estiloBotao(modoVencimento),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => trocarModo(false),
              icon: const Icon(Icons.trending_down, size: 18),
              label: const Text('Vai faltar'),
              style: estiloBotao(!modoVencimento),
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle estiloBotao(bool ativo) {
    return ElevatedButton.styleFrom(
      backgroundColor: ativo ? corAzul : Colors.grey.shade300,
      foregroundColor: ativo ? Colors.white : Colors.black87,
      elevation: ativo ? 2 : 0,
    );
  }

  // escolhe a janela de dias que vai pro parametro da api
  Widget montarFiltroDias() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Text('Vencendo nos próximos:'),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: dias,
            items: const [3, 7, 15, 30]
                .map((d) => DropdownMenuItem(value: d, child: Text('$d dias')))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => dias = v);
              carregar();
            },
          ),
        ],
      ),
    );
  }

  Widget montarLista() {
    if (carregando) return const Center(child: CircularProgressIndicator());
    if (lista.isEmpty) {
      return Center(
        child: Text(modoVencimento
            ? 'Nenhum produto vencendo nesse prazo.'
            : 'Nenhum produto em risco de faltar.'),
      );
    }
    return ListView.builder(
      itemCount: lista.length,
      itemBuilder: (_, i) {
        final p = lista[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: Icon(
              modoVencimento ? Icons.warning_amber : Icons.inventory_2,
              color: Colors.red,
            ),
            title: Text(p.nome),
            subtitle: Text(modoVencimento ? textoVencimento(p) : textoRisco(p)),
          ),
        );
      },
    );
  }

  String textoVencimento(Produto p) {
    final d = p.diasParaVencer();
    if (d == null) return 'validade: -';
    if (d < 0) return 'VENCIDO há ${-d} dia(s)  •  ${p.validade}';
    if (d == 0) return 'vence HOJE  •  ${p.validade}';
    return 'vence em $d dia(s)  •  ${p.validade}';
  }

  String textoRisco(Produto p) {
    return 'estoque: ${p.quantidade ?? 0} ${p.unidade ?? ""}  •  '
        'mínimo: ${p.estoqueMinimo ?? 0}';
  }
}
