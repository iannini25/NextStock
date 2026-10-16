import 'package:flutter/material.dart';
import '../main.dart';
import '../models/clima_dia.dart';
import '../models/lote.dart';
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
  Map<int, List<Lote>> lotesPorProduto = {}; // lotes vencendo de cada produto
  List<ClimaDia> climaDias = [];
  String cidade = '';
  String? avisoClima;
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final futuroProdutos = modoVencimento
          ? ApiService.listarProdutosVencendo(dias)
          : ApiService.listarProdutosEmRisco();
      final futuroClima = ApiService.listarClima();
      final r = await futuroProdutos;
      final clima = await futuroClima;
      // no modo vencendo, mostra embaixo de cada produto quais lotes estao vencendo.
      // se essa parte falhar, a lista de produtos aparece do mesmo jeito
      var porProduto = <int, List<Lote>>{};
      if (modoVencimento) {
        try {
          for (final l in await ApiService.listarLotesVencendo(dias)) {
            porProduto.putIfAbsent(l.idProduto, () => []).add(l);
          }
        } catch (_) {
          porProduto = {};
        }
      }
      if (!mounted) return;
      final hoje = DateTime.now();
      final base = DateTime(hoje.year, hoje.month, hoje.day);
      setState(() {
        lista = r;
        lotesPorProduto = porProduto;
        cidade = clima.cidade;
        avisoClima = clima.aviso;
        climaDias = clima.dias.where((d) {
          final dt = DateTime.tryParse(d.data);
          if (dt == null) return false;
          return !DateTime(dt.year, dt.month, dt.day).isBefore(base);
        }).take(7).toList();
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
          montarClima(),
          Expanded(child: montarLista()),
        ],
      ),
    );
  }

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

  Widget montarClima() {
    final titulo = cidade.isEmpty ? 'Clima dos próximos dias' : 'Clima em $cidade';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(
            modoVencimento
                ? 'calor antecipa perda; chuva costuma reduzir saída'
                : 'a lista de risco já usa a demanda prevista com esse clima',
            style: const TextStyle(fontSize: 12),
          ),
          if (avisoClima != null && avisoClima!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(avisoClima!, style: const TextStyle(fontSize: 12, color: Colors.orange)),
            ),
          const SizedBox(height: 8),
          if (climaDias.isEmpty)
            const Text('Sem dados de clima ainda.', style: TextStyle(fontSize: 12))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: climaDias.map(chipClima).toList(),
            ),
        ],
      ),
    );
  }

  Widget chipClima(ClimaDia c) {
    final chuva = c.chuvaMm?.toStringAsFixed(1) ?? '-';
    final temp = c.temperatura?.toStringAsFixed(0) ?? '-';
    return Chip(
      avatar: Icon(iconeClima(c.condicao), size: 18, color: corClima(c.condicao)),
      label: Text('${c.dataCurta()}  ${c.nomeCondicao()}  $chuva mm  $temp°'),
    );
  }

  IconData iconeClima(String condicao) {
    switch (condicao) {
      case 'chuva_forte':
      case 'chuva':
        return Icons.water_drop;
      case 'calor':
        return Icons.wb_sunny;
      case 'frio':
        return Icons.ac_unit;
      default:
        return Icons.cloud_outlined;
    }
  }

  Color corClima(String condicao) {
    switch (condicao) {
      case 'chuva_forte':
        return Colors.indigo;
      case 'chuva':
        return Colors.blue;
      case 'calor':
        return Colors.orange;
      case 'frio':
        return Colors.cyan;
      default:
        return Colors.blueGrey;
    }
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
            subtitle: Text(
              modoVencimento ? textoVencimento(p) : textoRisco(p),
            ),
          ),
        );
      },
    );
  }

  String textoVencimento(Produto p) {
    final d = p.diasParaVencer();
    String texto;
    if (d == null) {
      texto = 'validade: -';
    } else if (d < 0) {
      texto = 'VENCIDO há ${-d} dia(s)  •  ${p.validade}';
    } else if (d == 0) {
      texto = 'vence HOJE  •  ${p.validade}';
    } else {
      texto = 'vence em $d dia(s)  •  ${p.validade}';
    }
    // quais lotes (e quanto de cada) estao vencendo
    for (final l in lotesPorProduto[p.id] ?? <Lote>[]) {
      texto += '\n${l.titulo}: ${l.quantidadeAtual} ${l.unidade ?? ""} — ${l.textoValidade}';
    }
    return texto;
  }

  String textoRisco(Produto p) {
    var texto = 'estoque: ${p.quantidade ?? 0} ${p.unidade ?? ""}  •  '
        'mínimo: ${p.estoqueMinimo ?? 0}';
    if (p.motivo != null && p.motivo!.isNotEmpty) {
      texto += '\n${p.motivo}';
    }
    return texto;
  }
}
