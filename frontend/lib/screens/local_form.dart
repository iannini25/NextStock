import 'package:flutter/material.dart';
import '../models/armazenamento.dart';
import '../services/api_service.dart';

// cadastro e edicao de local de armazenamento (so admin)
class LocalForm extends StatefulWidget {
  final LocalArmazenamento? local;
  const LocalForm({super.key, this.local});

  @override
  State<LocalForm> createState() => _LocalFormState();
}

class _LocalFormState extends State<LocalForm> {
  final nome = TextEditingController();
  final tempMin = TextEditingController();
  final tempMax = TextEditingController();
  String tipo = 'refrigerado';
  bool salvando = false;

  @override
  void initState() {
    super.initState();
    final l = widget.local;
    if (l != null) {
      nome.text = l.nome;
      tipo = l.tipo;
      tempMin.text = l.tempMin.toStringAsFixed(1);
      tempMax.text = l.tempMax.toStringAsFixed(1);
    } else {
      preencherFaixa(tipo);
    }
  }

  @override
  void dispose() {
    nome.dispose();
    tempMin.dispose();
    tempMax.dispose();
    super.dispose();
  }

  void preencherFaixa(String t) {
    final (min, max) = faixasPadrao[t]!;
    tempMin.text = min.toStringAsFixed(1);
    tempMax.text = max.toStringAsFixed(1);
  }

  // trocou o tipo: se a faixa ainda era a sugerida do tipo anterior, troca pela do novo
  void trocarTipo(String? novo) {
    if (novo == null) return;
    final (minAntes, maxAntes) = faixasPadrao[tipo]!;
    final eraPadrao = lerNumero(tempMin.text) == minAntes && lerNumero(tempMax.text) == maxAntes;
    setState(() {
      tipo = novo;
      if (eraPadrao || tempMin.text.isEmpty || tempMax.text.isEmpty) preencherFaixa(novo);
    });
  }

  double? lerNumero(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  void mostrarErro(Object e) {
    if (!mounted) return;
    final msg = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  String? validar() {
    if (nome.text.trim().isEmpty) return 'informe o nome do local';
    final min = lerNumero(tempMin.text);
    final max = lerNumero(tempMax.text);
    if (min == null || max == null) return 'informe a temperatura mínima e a máxima';
    if (min >= max) return 'a temperatura mínima tem que ser menor que a máxima';
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
      await ApiService.salvarLocal(
        id: widget.local?.id,
        nome: nome.text.trim(),
        tipo: tipo,
        tempMin: lerNumero(tempMin.text),
        tempMax: lerNumero(tempMax.text),
      );
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
      appBar: AppBar(title: Text(widget.local == null ? 'Novo local' : 'Editar local')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          campo(nome, 'Nome * (ex.: Geladeira laticínios)'),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              initialValue: tipo,
              decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
              items: tiposLocal.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: trocarTipo,
            ),
          ),
          Row(
            children: [
              Expanded(child: campo(tempMin, 'Mínima (°C) *', numero: true)),
              const SizedBox(width: 12),
              Expanded(child: campo(tempMax, 'Máxima (°C) *', numero: true)),
            ],
          ),
          const Text(
            'Fora dessa faixa o sistema avisa e mostra os produtos guardados aqui.',
            style: TextStyle(fontSize: 12),
          ),
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
        keyboardType: numero ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
