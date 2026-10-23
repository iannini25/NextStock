import 'package:flutter/material.dart';
import '../models/evento.dart';
import '../services/api_service.dart';

class EventoForm extends StatefulWidget {
  const EventoForm({super.key});

  @override
  State<EventoForm> createState() => _EventoFormState();
}

class _EventoFormState extends State<EventoForm> {
  final nome = TextEditingController();
  final inicio = TextEditingController();
  final fim = TextEditingController();
  final impacto = TextEditingController();
  bool salvando = false;

  void mostrarErro(Object e) {
    if (!mounted) return;
    final msg = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> salvar() async {
    setState(() => salvando = true);
    final ev = Evento(
      nome: nome.text,
      dataInicio: inicio.text,
      dataFim: fim.text,
      impactoPercentual: int.tryParse(impacto.text) ?? 0,
    );
    try {
      await ApiService.criarEvento(ev);
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
      appBar: AppBar(title: const Text('Novo evento')),
      // no computador o formulario nao estica na tela toda
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              campo(nome, 'Nome *'),
              campo(inicio, 'Data início (aaaa-mm-dd) *'),
              campo(fim, 'Data fim (aaaa-mm-dd) *'),
              campo(impacto, 'Impacto na demanda (%)', numero: true),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: salvando ? null : salvar,
                child: Text(salvando ? 'Salvando...' : 'Salvar'),
              ),
            ],
          ),
        ),
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
