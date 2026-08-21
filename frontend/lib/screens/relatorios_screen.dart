import 'package:flutter/material.dart';
import '../models/relatorio.dart';
import '../services/api_service.dart';

class RelatoriosScreen extends StatefulWidget {
  const RelatoriosScreen({super.key});

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen> {
  String tipo = 'consumo';
  int dias = 30;
  RelatorioConsumo? consumo;
  RelatorioDesempenho? desempenho;
  List<Tendencia> tendencias = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      if (tipo == 'consumo') {
        consumo = await ApiService.relatorioConsumo(dias);
      } else if (tipo == 'desempenho') {
        desempenho = await ApiService.relatorioDesempenho(dias);
      } else {
        tendencias = await ApiService.relatorioTendencias(dias);
      }
      if (!mounted) return;
      setState(() => carregando = false);
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
        title: const Text('Relatórios'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: carregar),
        ],
      ),
      body: Column(
        children: [
          montarFiltros(),
          Expanded(child: montarLista()),
        ],
      ),
    );
  }

  Widget montarFiltros() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Text('Relatório:'),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: tipo,
            items: const [
              DropdownMenuItem(value: 'consumo', child: Text('Consumo')),
              DropdownMenuItem(value: 'desempenho', child: Text('Desempenho')),
              DropdownMenuItem(value: 'tendencias', child: Text('Tendências')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => tipo = v);
              carregar();
            },
          ),
          const SizedBox(width: 16),
          const Text('Dias:'),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: dias,
            items: const [7, 15, 30, 60]
                .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
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
    if (tipo == 'consumo') {
      return montarConsumo();
    } else if (tipo == 'desempenho') {
      return montarDesempenho();
    } else {
      return montarTendencias();
    }
  }

  Widget montarConsumo() {
    final r = consumo;
    if (r == null || r.itens.isEmpty) {
      return const Center(child: Text('Nenhuma venda no período.'));
    }
    final itens = <Widget>[
      ListTile(
        title: Text(
          'total vendido: ${r.totalVendido}  •  faturamento: R\$ ${r.faturamentoTotal.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    ];
    for (final item in r.itens) {
      itens.add(Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          title: Text(item.produtoNome),
          subtitle: Text(
            '${item.categoriaNome ?? "sem categoria"}  •  vendidos: ${item.quantidadeVendida}  •  '
            'R\$ ${item.faturamento.toStringAsFixed(2)}  •  ${item.percentualDoTotal.toStringAsFixed(1)}% do total',
          ),
        ),
      ));
    }
    return ListView(children: itens);
  }

  Widget montarDesempenho() {
    final r = desempenho;
    if (r == null) {
      return const Center(child: Text('Nenhum dado no período.'));
    }
    final itens = <Widget>[];
    itens.add(montarTitulo('Mais vendidos'));
    for (final item in r.maisVendidos) {
      itens.add(montarItemVenda(item));
    }
    itens.add(montarTitulo('Menos vendidos'));
    for (final item in r.menosVendidos) {
      itens.add(montarItemVenda(item));
    }
    itens.add(montarTitulo('Margem'));
    for (final item in r.margens) {
      itens.add(Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          title: Text(item.produtoNome),
          subtitle: Text(
            'custo R\$ ${item.precoCusto?.toStringAsFixed(2) ?? "-"}  •  '
            'venda R\$ ${item.precoVenda?.toStringAsFixed(2) ?? "-"}  •  '
            'margem ${item.margemPercentual.toStringAsFixed(1)}%',
          ),
        ),
      ));
    }
    return ListView(children: itens);
  }

  Widget montarTitulo(String texto) {
    return ListTile(
      title: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget montarItemVenda(ItemDesempenho item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(item.produtoNome),
        subtitle: Text(
          'vendidos: ${item.quantidadeVendida}  •  R\$ ${item.faturamento.toStringAsFixed(2)}',
        ),
      ),
    );
  }

  Widget montarTendencias() {
    if (tendencias.isEmpty) {
      return const Center(child: Text('Nenhum produto pra comparar.'));
    }
    return ListView.builder(
      itemCount: tendencias.length,
      itemBuilder: (_, i) {
        final t = tendencias[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: iconeTendencia(t.tendencia),
            title: Text(t.produtoNome),
            subtitle: Text(
              'anterior: ${t.vendasPeriodoAnterior}  •  atual: ${t.vendasPeriodoAtual}  •  '
              'variação: ${t.variacaoPercentual.toStringAsFixed(1)}%',
            ),
          ),
        );
      },
    );
  }

  Icon iconeTendencia(String tendencia) {
    if (tendencia == 'subindo') {
      return const Icon(Icons.trending_up, color: Colors.green);
    }
    if (tendencia == 'caindo') {
      return const Icon(Icons.trending_down, color: Colors.red);
    }
    return const Icon(Icons.trending_flat, color: Colors.grey);
  }
}
