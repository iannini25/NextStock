import 'package:flutter/material.dart';
import '../models/perda.dart';
import '../services/api_service.dart';
import 'perda_form.dart';

// perdas e descartes: quanto se perdeu no periodo (em R$), por motivo, e cada registro
class PerdasScreen extends StatefulWidget {
  const PerdasScreen({super.key});

  @override
  State<PerdasScreen> createState() => _PerdasScreenState();
}

class _PerdasScreenState extends State<PerdasScreen> {
  int dias = 30;
  ResumoPerdas? resumo;
  List<Perda> perdas = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  String inicio() {
    final d = DateTime.now().subtract(Duration(days: dias));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final r = await ApiService.resumoPerdas(dias);
      final lista = await ApiService.listarPerdas(inicio: inicio());
      if (!mounted) return;
      setState(() {
        resumo = r;
        perdas = lista.itens;
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

  Future<void> registrar() async {
    final salvou = await Navigator.push(context, MaterialPageRoute(builder: (_) => const PerdaForm()));
    if (salvou == true) carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perdas e descartes'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: carregar)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: registrar,
        icon: const Icon(Icons.add),
        label: const Text('Registrar perda'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                const Text('Período:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: dias,
                  items: const [7, 30, 90]
                      .map((d) => DropdownMenuItem(value: d, child: Text('últimos $d dias')))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => dias = v);
                    carregar();
                  },
                ),
              ],
            ),
          ),
          Expanded(child: carregando ? const Center(child: CircularProgressIndicator()) : montarConteudo()),
        ],
      ),
    );
  }

  Widget montarConteudo() {
    final r = resumo;
    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        if (r != null)
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Prejuízo no período: R\$ ${r.valorTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                  Text('${r.quantidadeTotal} item(ns) em ${r.registros} registro(s)'),
                  if (r.porMotivo.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final m in r.porMotivo)
                          Chip(label: Text('${m.nome}: R\$ ${m.valor.toStringAsFixed(2)} (${m.quantidade})')),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (perdas.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Nenhuma perda registrada nesse período.')),
          )
        else
          for (final p in perdas) montarItem(p),
      ],
    );
  }

  Widget montarItem(Perda p) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.delete_sweep, color: Colors.red),
        title: Text('−${p.quantidade} ${p.unidade ?? ""}  •  ${p.produtoNome ?? ""}  •  R\$ ${p.valorTotal.toStringAsFixed(2)}'),
        subtitle: Text([
          '${p.nomeTipo}  •  ${p.nomeMotivo}${p.lote != null ? "  •  ${p.lote}" : ""}',
          '${p.quando}${p.usuario != null ? "  •  por ${p.usuario}" : ""}',
          if (p.observacao != null) p.observacao!,
        ].join('\n')),
        isThreeLine: true,
      ),
    );
  }
}
