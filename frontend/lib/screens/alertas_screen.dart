import 'package:flutter/material.dart';
import '../main.dart';
import '../models/alerta.dart';
import '../models/armazenamento.dart';
import '../models/clima_dia.dart';
import '../models/lote.dart';
import '../models/produto.dart';
import '../services/api_service.dart';

// Tela dos alertas. Tem tres modos: o que ta vencendo, o que vai faltar e o que esta sobrando (excesso).
class AlertasScreen extends StatefulWidget {
  // abre a tela de Armazenamento (pelo aviso de temperatura no topo)
  final VoidCallback? aoAbrirArmazenamento;
  const AlertasScreen({super.key, this.aoAbrirArmazenamento});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

// cor de cada prioridade (usada nos selos de Vai faltar e Excesso)
Color corPrioridade(String? prioridade) {
  switch (prioridade) {
    case 'alta':
      return Colors.red;
    case 'media':
      return Colors.orange;
    default:
      return Colors.blueGrey;
  }
}

class _AlertasScreenState extends State<AlertasScreen> {
  String modo = 'vencendo'; // vencendo | falta | excesso
  int dias = 7;
  int diasCobertura = 30; // no modo excesso: estoque que cobre mais que isso e demais
  List<Produto> lista = [];
  List<AlertaExcesso> excessos = [];
  List<LocalArmazenamento> temperatura = []; // locais fora da faixa ou sem leitura (aviso no topo)
  Map<int, List<Lote>> lotesPorProduto = {}; // lotes vencendo de cada produto
  List<ClimaDia> climaDias = [];
  String cidade = '';
  String? avisoClima;
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
    carregarTemperatura();
  }

  // aviso de temperatura no topo. se der erro, so nao aparece (nao atrapalha os alertas)
  Future<void> carregarTemperatura() async {
    try {
      final r = await ApiService.alertasTemperatura();
      if (mounted) setState(() => temperatura = r);
    } catch (_) {
      if (mounted) setState(() => temperatura = []);
    }
  }

  bool get modoVencimento => modo == 'vencendo';
  bool get modoExcesso => modo == 'excesso';

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final futuroProdutos = modoExcesso
          ? Future.value(<Produto>[])
          : modoVencimento
              ? ApiService.listarProdutosVencendo(dias)
              : ApiService.listarProdutosEmRisco();
      final futuroExcesso = modoExcesso
          ? ApiService.listarAlertasExcesso(diasCobertura: diasCobertura)
          : Future.value(<AlertaExcesso>[]);
      final futuroClima = ApiService.listarClima();
      final r = await futuroProdutos;
      final ex = await futuroExcesso;
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
        excessos = ex;
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

  void trocarModo(String novo) {
    setState(() => modo = novo);
    carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              carregar();
              carregarTemperatura();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (temperatura.isNotEmpty) montarAvisoTemperatura(),
          montarBotoes(),
          if (modoVencimento) montarFiltroDias(),
          if (modoExcesso) montarFiltroCobertura(),
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
              onPressed: () => trocarModo('vencendo'),
              icon: const Icon(Icons.event_busy, size: 18),
              label: const Text('Vencendo'),
              style: estiloBotao(modoVencimento),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => trocarModo('falta'),
              icon: const Icon(Icons.trending_down, size: 18),
              label: const Text('Vai faltar'),
              style: estiloBotao(modo == 'falta'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => trocarModo('excesso'),
              icon: const Icon(Icons.inventory, size: 18),
              label: const Text('Excesso'),
              style: estiloBotao(modoExcesso),
            ),
          ),
        ],
      ),
    );
  }

  Widget montarAvisoTemperatura() {
    final fora = temperatura.where((l) => l.status == 'fora_da_faixa').length;
    final cor = fora > 0 ? Colors.red : Colors.orange;
    return Card(
      color: cor.withValues(alpha: 0.10),
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: ListTile(
        leading: Icon(Icons.thermostat, color: cor),
        title: Text('${temperatura.length} local(is) com problema de temperatura'),
        subtitle: Text(temperatura.map((l) => l.mensagem).join('\n')),
        trailing: widget.aoAbrirArmazenamento == null
            ? null
            : TextButton(onPressed: widget.aoAbrirArmazenamento, child: const Text('Ver')),
      ),
    );
  }

  Widget montarFiltroCobertura() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Flexible(child: Text('Estoque ideal: até')),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: diasCobertura,
            items: const [15, 30, 60, 90]
                .map((d) => DropdownMenuItem(value: d, child: Text('$d dias de venda')))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => diasCobertura = v);
              carregar();
            },
          ),
        ],
      ),
    );
  }

  ButtonStyle estiloBotao(bool ativo) {
    return ElevatedButton.styleFrom(
      // o botao apagado usa as cores do tema pra nao ficar claro demais no tema escuro
      backgroundColor: ativo ? corAzul : Theme.of(context).colorScheme.surfaceContainerHighest,
      foregroundColor: ativo ? Colors.white : Theme.of(context).colorScheme.onSurface,
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
                : modoExcesso
                    ? 'o excesso é calculado com a venda prevista para esse clima'
                    : 'a lista de risco já usa a demanda prevista com esse clima',
            style: const TextStyle(fontSize: 12),
          ),
          if (avisoClima != null && avisoClima!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(avisoClima!, style: const TextStyle(fontSize: 12, color: corAviso)),
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
    if (modoExcesso) return montarListaExcesso();
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
            trailing: !modoVencimento && p.prioridade != null
                ? seloPrioridade(p.prioridade!, classe: p.classeAbc)
                : null,
          ),
        );
      },
    );
  }

  Widget montarListaExcesso() {
    if (excessos.isEmpty) {
      return const Center(child: Text('Nenhum produto com estoque sobrando.'));
    }
    final total = excessos.fold<double>(0, (s, a) => s + a.valorEmRisco);
    return ListView.builder(
      itemCount: excessos.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          // resumo no topo, igual ao da tela de perdas
          return Card(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${excessos.length} alerta(s)  •  R\$ ${total.toStringAsFixed(2)} em risco',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          );
        }
        final a = excessos[i - 1];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: Icon(
              a.perecivel ? Icons.hourglass_bottom : Icons.inventory,
              color: corPrioridade(a.prioridade),
            ),
            title: Text(a.produtoNome),
            subtitle: Text(textoExcesso(a)),
            trailing: seloPrioridade(a.prioridade, classe: a.classeAbc),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  String textoExcesso(AlertaExcesso a) {
    final un = a.unidade ?? 'UN';
    var texto = '${a.nomeTipo}: ${a.quantidadeEmRisco} $un  •  R\$ ${a.valorEmRisco.toStringAsFixed(2)} em risco';
    texto += '\n${a.mensagem}';
    return texto;
  }

  // selo "Alta / Média / Baixa" com a classe ABC embaixo
  Widget seloPrioridade(String prioridade, {String? classe}) {
    final cor = corPrioridade(prioridade);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.12),
            border: Border.all(color: cor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            nomesPrioridade[prioridade] ?? prioridade,
            style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        if (classe != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('classe $classe', style: const TextStyle(fontSize: 11)),
          ),
      ],
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
      texto += '\n${l.titulo}: ${l.quantidadeAtual} ${l.unidade ?? ""} - ${l.textoValidade}';
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
