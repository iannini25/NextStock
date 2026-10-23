import 'package:flutter/material.dart';
import '../models/lote.dart';
import '../models/produto.dart';
import '../services/api_service.dart';

// sem lote = entrada de mercadoria nova. com lote = corrigir codigo ou validade daquele lote
class LoteForm extends StatefulWidget {
  final Produto produto;
  final Lote? lote;
  const LoteForm({super.key, required this.produto, this.lote});

  @override
  State<LoteForm> createState() => _LoteFormState();
}

class _LoteFormState extends State<LoteForm> {
  final quantidade = TextEditingController();
  final validade = TextEditingController();
  final codigo = TextEditingController();
  final custo = TextEditingController();
  final dataEntrada = TextEditingController();
  bool salvando = false;

  bool get corrigindo => widget.lote != null;

  @override
  void initState() {
    super.initState();
    final l = widget.lote;
    if (l != null) {
      validade.text = l.dataValidade ?? '';
      codigo.text = l.codigoLote ?? '';
    } else {
      custo.text = widget.produto.precoCusto?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [quantidade, validade, codigo, custo, dataEntrada]) {
      c.dispose();
    }
    super.dispose();
  }

  void mostrarErro(Object e) {
    if (!mounted) return;
    final msg = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  String? vazioViraNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> salvar() async {
    final qtd = int.tryParse(quantidade.text.trim());
    if (!corrigindo && (qtd == null || qtd <= 0)) {
      mostrarErro(Exception('informe uma quantidade maior que zero'));
      return;
    }
    setState(() => salvando = true);
    try {
      if (corrigindo) {
        await ApiService.corrigirLote(widget.lote!.id,
            codigoLote: vazioViraNull(codigo), dataValidade: vazioViraNull(validade));
      } else {
        await ApiService.registrarEntrada(
          idProduto: widget.produto.id!,
          quantidade: qtd!,
          dataValidade: vazioViraNull(validade),
          codigoLote: vazioViraNull(codigo),
          custoUnitario: double.tryParse(custo.text.replaceAll(',', '.')),
          dataEntrada: vazioViraNull(dataEntrada),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => salvando = false);
      mostrarErro(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(corrigindo ? 'Corrigir ${widget.lote!.titulo}' : 'Nova entrada - ${widget.produto.nome}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (corrigindo)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('A quantidade não muda por aqui: entra pela entrada de mercadoria e sai pelas vendas.'),
            )
          else
            campo(quantidade, 'Quantidade *', numero: true),
          campo(validade, 'Validade (aaaa-mm-dd, vazio = sem validade)'),
          campo(codigo, 'Código do lote (opcional)'),
          if (!corrigindo) ...[
            campo(custo, 'Custo unitário', numero: true),
            campo(dataEntrada, 'Data de entrada (aaaa-mm-dd, vazio = hoje)'),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: salvando ? null : salvar,
            child: Text(salvando ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
    );
  }

  Widget campo(TextEditingController c, String label, {bool numero = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: numero ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
