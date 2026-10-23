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
  CurvaAbc? curvaAbc;
  String criterioAbc = 'faturamento';
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
      } else if (tipo == 'curva_abc') {
        curvaAbc = await ApiService.relatorioCurvaAbc(dias, criterioAbc);
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Relatório:'),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: tipo,
            items: const [
              DropdownMenuItem(value: 'consumo', child: Text('Consumo')),
              DropdownMenuItem(value: 'desempenho', child: Text('Desempenho')),
              DropdownMenuItem(value: 'tendencias', child: Text('Tendências')),
              DropdownMenuItem(value: 'curva_abc', child: Text('Curva ABC')),
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
          // a curva pode ser pelo dinheiro (faturamento) ou pelas unidades vendidas
          if (tipo == 'curva_abc') ...[
            const SizedBox(width: 16),
            const Text('Por:'),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: criterioAbc,
              items: const [
                DropdownMenuItem(value: 'faturamento', child: Text('Faturamento')),
                DropdownMenuItem(value: 'quantidade', child: Text('Quantidade')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => criterioAbc = v);
                carregar();
              },
            ),
          ],
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
    } else if (tipo == 'curva_abc') {
      return montarCurvaAbc();
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
      // resumo no topo, igual ao da tela de perdas
      Card(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'total vendido: ${r.totalVendido}  •  faturamento: R\$ ${r.faturamentoTotal.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
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
      title: Text(texto, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.primary)),
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

  static const coresAbc = {'A': Colors.green, 'B': Colors.orange, 'C': Colors.grey};

  Widget montarCurvaAbc() {
    final r = curvaAbc;
    if (r == null || r.itens.isEmpty) {
      return const Center(child: Text('Nenhum produto pra classificar.'));
    }
    final porFaturamento = r.criterio == 'faturamento';
    final itens = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Text(
          porFaturamento
              ? 'A = produtos que fazem os primeiros 80% do faturamento • B = até 95% • C = o resto'
              : 'A = produtos que fazem as primeiras 80% das unidades vendidas • B = até 95% • C = o resto',
          style: const TextStyle(fontSize: 12),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in ['A', 'B', 'C'])
              Chip(
                avatar: CircleAvatar(backgroundColor: coresAbc[c], child: Text(c, style: const TextStyle(color: Colors.white))),
                label: Text('${r.resumo[c]!.produtos} produto(s) • '
                    '${r.resumo[c]!.percentualValor.toStringAsFixed(1)}% do ${porFaturamento ? "faturamento" : "volume"}'),
              ),
          ],
        ),
      ),
    ];
    for (final item in r.itens) {
      final valor = porFaturamento ? 'R\$ ${item.faturamento.toStringAsFixed(2)}' : '${item.quantidadeVendida} vendidos';
      itens.add(Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: coresAbc[item.classe],
            child: Text(item.classe, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          title: Text('${item.posicao}º  ${item.produtoNome}'),
          subtitle: Text(
            '$valor  •  ${item.percentual.toStringAsFixed(1)}% do total  •  '
            'acumulado ${item.percentualAcumulado.toStringAsFixed(1)}%',
          ),
        ),
      ));
    }
    return ListView(children: itens);
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
