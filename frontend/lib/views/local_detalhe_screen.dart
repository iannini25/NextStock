import 'package:flutter/material.dart';
import '../models/armazenamento.dart';
import '../services/api_service.dart';
import '../services/sessao.dart';
import 'armazenamento_screen.dart';
import 'local_form.dart';
import 'perda_form.dart';

// detalhe de um local: situacao, lancar leitura, produtos guardados (com atalho pra registrar perda)
// e o historico de leituras
class LocalDetalheScreen extends StatefulWidget {
  final int idLocal;
  const LocalDetalheScreen({super.key, required this.idLocal});

  @override
  State<LocalDetalheScreen> createState() => _LocalDetalheScreenState();
}

class _LocalDetalheScreenState extends State<LocalDetalheScreen> {
  final temperatura = TextEditingController();
  final umidade = TextEditingController();
  LocalArmazenamento? local;
  List<LeituraTemperatura> leituras = [];
  bool carregando = true;
  bool registrando = false;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  @override
  void dispose() {
    temperatura.dispose();
    umidade.dispose();
    super.dispose();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final futuroLocal = ApiService.buscarLocal(widget.idLocal);
      final futuroLeituras = ApiService.listarLeituras(widget.idLocal);
      final l = await futuroLocal;
      final h = await futuroLeituras;
      if (!mounted) return;
      setState(() {
        local = l;
        leituras = h;
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  double? lerNumero(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  Future<void> registrarLeitura() async {
    final t = lerNumero(temperatura.text);
    if (t == null) {
      mostrarErro(Exception('informe a temperatura (ex.: 4,5)'));
      return;
    }
    final u = umidade.text.trim().isEmpty ? null : lerNumero(umidade.text);
    if (umidade.text.trim().isNotEmpty && u == null) {
      mostrarErro(Exception('umidade precisa ser um número'));
      return;
    }
    setState(() => registrando = true);
    try {
      final depois = await ApiService.registrarLeitura(widget.idLocal, t, umidade: u);
      if (!mounted) return;
      temperatura.clear();
      umidade.clear();
      final fora = depois.status == 'fora_da_faixa';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(fora ? 'Fora da faixa! ${depois.mensagem}' : 'Leitura registrada: ${graus(t)}'),
        backgroundColor: fora ? Colors.red : null,
      ));
      setState(() => registrando = false);
      carregar();
    } catch (e) {
      if (!mounted) return;
      setState(() => registrando = false);
      mostrarErro(e);
    }
  }

  Future<void> registrarPerda(ProdutoNoLocal p) async {
    final salvou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PerdaForm(produto: p.paraProduto(), motivoInicial: 'temperatura')),
    );
    if (salvou == true) carregar();
  }

  Future<void> editar() async {
    final salvou = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => LocalForm(local: local)));
    if (salvou == true) carregar();
  }

  Future<void> desativarOuReativar() async {
    final l = local!;
    if (l.ativo) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Desativar local?'),
          content: Text('"${l.nome}" para de receber leituras e de gerar alertas. '
              'O histórico e os produtos continuam ligados a ele.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Desativar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      if (l.ativo) {
        await ApiService.desativarLocal(l.id);
      } else {
        await ApiService.salvarLocal(
            id: l.id, nome: l.nome, tipo: l.tipo, tempMin: l.tempMin, tempMax: l.tempMax, ativo: true);
      }
      carregar();
    } catch (e) {
      mostrarErro(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = local;
    return Scaffold(
      appBar: AppBar(
        title: Text(l?.nome ?? 'Local'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: carregar),
          if (Sessao.ehAdmin && l != null) ...[
            IconButton(tooltip: 'Editar', icon: const Icon(Icons.edit), onPressed: editar),
            IconButton(
              tooltip: l.ativo ? 'Desativar' : 'Reativar',
              icon: Icon(l.ativo ? Icons.block : Icons.check_circle_outline),
              onPressed: desativarOuReativar,
            ),
          ],
        ],
      ),
      body: carregando && l == null
          ? const Center(child: CircularProgressIndicator())
          : l == null
              ? const Center(child: Text('Não foi possível carregar o local.'))
              // no computador o conteudo fica no meio e nao estica na tela toda
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        montarSituacao(l),
                        if (l.ativo) montarLeitura(),
                        montarProdutos(l),
                        montarHistorico(l),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget titulo(String texto) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(texto, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.primary)),
      );

  Widget montarSituacao(LocalArmazenamento l) {
    return Card(
      child: ListTile(
        leading: Icon(iconeTipoLocal(l.tipo), color: corStatusLocal(l.status), size: 32),
        title: Row(
          children: [
            Flexible(child: Text('${l.nomeTipo}  •  faixa ${l.faixa}')),
            const SizedBox(width: 8),
            seloStatusLocal(l),
          ],
        ),
        // o numero do local e o que o sensor (ou o simulador) usa
        subtitle: Text('${l.mensagem}\nLocal #${l.id}'),
        isThreeLine: true,
      ),
    );
  }

  Widget montarLeitura() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        titulo('Registrar leitura'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: temperatura,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Temperatura (°C) *', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: umidade,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Umidade (%)', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: registrando ? null : registrarLeitura,
          icon: const Icon(Icons.thermostat),
          label: Text(registrando ? 'Registrando...' : 'Registrar leitura'),
        ),
      ],
    );
  }

  Widget montarProdutos(LocalArmazenamento l) {
    final emRisco = l.status == 'fora_da_faixa';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        titulo('Produtos guardados aqui (R\$ ${l.valorEmEstoque.toStringAsFixed(2)})'),
        if (l.produtos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('Nenhum produto ligado a este local. Escolha o local no cadastro do produto.'),
          ),
        for (final p in l.produtos)
          Card(
            child: ListTile(
              leading: Icon(Icons.inventory_2, color: emRisco ? Colors.red : null),
              title: Text(p.nome),
              subtitle: Text('${p.quantidade} ${p.unidade ?? "UN"}  •  R\$ ${p.valor.toStringAsFixed(2)}'),
              trailing: p.quantidade > 0
                  ? TextButton.icon(
                      onPressed: () => registrarPerda(p),
                      icon: const Icon(Icons.delete_sweep, size: 18),
                      label: const Text('Registrar perda'),
                    )
                  : null,
            ),
          ),
      ],
    );
  }

  Widget montarHistorico(LocalArmazenamento l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        titulo('Histórico de leituras'),
        if (leituras.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('Nenhuma leitura ainda.'),
          ),
        for (final h in leituras)
          ListTile(
            dense: true,
            leading: Icon(
              h.foraDaFaixa ? Icons.warning_amber : Icons.check_circle_outline,
              color: h.foraDaFaixa ? Colors.red : Colors.green,
            ),
            title: Text(
              graus(h.temperatura) + (h.umidade != null ? '  •  ${h.umidade!.toStringAsFixed(0)}%' : ''),
              style: TextStyle(
                color: h.foraDaFaixa ? Colors.red : null,
                fontWeight: h.foraDaFaixa ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text('${dataHoraCurta(h.dataHora)}  •  ${h.nomeOrigem}${h.usuario != null ? '  •  ${h.usuario}' : ''}'),
          ),
      ],
    );
  }
}
