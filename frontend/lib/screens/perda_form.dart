import 'package:flutter/material.dart';
import '../models/lote.dart';
import '../models/perda.dart';
import '../models/produto.dart';
import '../services/api_service.dart';

// registra uma perda ou um descarte de um lote. abre vazio (escolhe produto e lote)
// ou ja com o lote escolhido (atalho "Descartar" de um lote vencido)
class PerdaForm extends StatefulWidget {
  final Produto? produto;
  final Lote? lote;
  final String tipoInicial;
  final String? motivoInicial;
  const PerdaForm({super.key, this.produto, this.lote, this.tipoInicial = 'perda', this.motivoInicial});

  @override
  State<PerdaForm> createState() => _PerdaFormState();
}

class _PerdaFormState extends State<PerdaForm> {
  final quantidade = TextEditingController();
  final observacao = TextEditingController();
  List<Produto> produtos = [];
  List<Lote> lotes = [];
  Produto? produto;
  Lote? lote;
  late String tipo = widget.tipoInicial;
  late String? motivo = widget.motivoInicial;
  bool salvando = false;

  bool get loteFixo => widget.lote != null;

  @override
  void initState() {
    super.initState();
    produto = widget.produto;
    lote = widget.lote;
    if (lote != null) {
      quantidade.text = '${lote!.quantidadeAtual}'; // descartar: normalmente sai o lote inteiro
    } else {
      carregarProdutos();
    }
  }

  @override
  void dispose() {
    quantidade.dispose();
    observacao.dispose();
    super.dispose();
  }

  Future<void> carregarProdutos() async {
    try {
      final lista = await ApiService.listarProdutos();
      if (!mounted) return;
      setState(() => produtos = lista.where((p) => (p.quantidade ?? 0) > 0).toList());
    } catch (e) {
      mostrarErro(e);
    }
  }

  Future<void> escolherProduto(int? id) async {
    setState(() {
      produto = produtos.where((p) => p.id == id).firstOrNull;
      lote = null;
      lotes = [];
    });
    if (produto == null) return;
    try {
      final r = await ApiService.listarLotes(produto!.id!);
      if (!mounted) return;
      setState(() => lotes = r.lotes);
    } catch (e) {
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

  // custo do lote; sem custo no lote, o do produto
  double? get custo => lote?.custoUnitario ?? produto?.precoCusto;

  String? validar() {
    if (lote == null) return 'escolha o lote';
    final qtd = int.tryParse(quantidade.text.trim());
    if (qtd == null || qtd <= 0) return 'informe uma quantidade maior que zero';
    if (qtd > lote!.quantidadeAtual) return 'o lote só tem ${lote!.quantidadeAtual} em estoque';
    if (motivo == null) return 'escolha o motivo';
    return null;
  }

  Future<void> salvar() async {
    final erro = validar();
    if (erro != null) {
      mostrarErro(Exception(erro));
      return;
    }
    setState(() => salvando = true);
    try {
      final aviso = await ApiService.registrarPerda(
        idLote: lote!.id,
        quantidade: int.parse(quantidade.text.trim()),
        tipo: tipo,
        motivo: motivo!,
        observacao: observacao.text.trim().isEmpty ? null : observacao.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(aviso ?? '${tiposPerda[tipo]} registrado'),
        backgroundColor: aviso != null ? Colors.orange : null,
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => salvando = false);
      mostrarErro(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qtd = int.tryParse(quantidade.text.trim()) ?? 0;
    final valor = custo == null ? null : qtd * custo!;
    return Scaffold(
      appBar: AppBar(title: Text(tipo == 'descarte' ? 'Registrar descarte' : 'Registrar perda')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (loteFixo)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${produto?.nome ?? lote!.produtoNome ?? ""}  •  ${lote!.titulo}  •  '
                'saldo: ${lote!.quantidadeAtual}  •  ${lote!.textoValidade}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          else ...[
            seletor<int>(
              rotulo: 'Produto *',
              valor: produto?.id,
              itens: {for (final p in produtos) p.id!: '${p.nome} (estoque: ${p.quantidade ?? 0})'},
              aoMudar: escolherProduto,
            ),
            seletor<int>(
              rotulo: 'Lote *',
              valor: lote?.id,
              itens: {
                for (final l in lotes) l.id: '${l.titulo} — saldo ${l.quantidadeAtual} — ${l.textoValidade}',
              },
              aoMudar: (id) => setState(() => lote = lotes.where((l) => l.id == id).firstOrNull),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: quantidade,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}), // atualiza o valor
              decoration: const InputDecoration(labelText: 'Quantidade *', border: OutlineInputBorder()),
            ),
          ),
          seletor<String>(
            rotulo: 'Tipo',
            valor: tipo,
            itens: tiposPerda,
            aoMudar: (v) => setState(() => tipo = v ?? tipo),
          ),
          seletor<String>(
            rotulo: 'Motivo *',
            valor: motivo,
            itens: motivosPerda,
            aoMudar: (v) => setState(() => motivo = v),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: observacao,
              decoration: const InputDecoration(labelText: 'Observação (opcional)', border: OutlineInputBorder()),
            ),
          ),
          // o valor aparece antes de confirmar
          Text(
            valor == null
                ? 'Valor da perda: sem custo cadastrado (fica R\$ 0,00)'
                : 'Valor da perda: R\$ ${valor.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: salvando ? null : salvar,
            child: Text(salvando ? 'Salvando...' : 'Confirmar'),
          ),
        ],
      ),
    );
  }

  Widget seletor<T>({
    required String rotulo,
    required T? valor,
    required Map<T, String> itens,
    required ValueChanged<T?> aoMudar,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        key: ValueKey('$rotulo-${itens.length}-$valor'), // recria quando a lista de opcoes muda
        initialValue: itens.containsKey(valor) ? valor : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: rotulo, border: const OutlineInputBorder()),
        items: itens.entries.map((e) => DropdownMenuItem<T>(value: e.key, child: Text(e.value))).toList(),
        onChanged: aoMudar,
      ),
    );
  }
}
