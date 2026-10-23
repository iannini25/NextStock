import 'package:flutter/material.dart';
import '../models/evento.dart';
import '../services/api_service.dart';
import '../services/sessao.dart';
import 'evento_form.dart';

class EventosScreen extends StatefulWidget {
  const EventosScreen({super.key});

  @override
  State<EventosScreen> createState() => _EventosScreenState();
}

class _EventosScreenState extends State<EventosScreen> {
  List<Evento> lista = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final r = await ApiService.listarEventos();
      if (!mounted) return;
      setState(() {
        lista = r;
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

  Future<void> abrirForm() async {
    final salvou = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EventoForm()),
    );
    if (salvou == true) carregar();
  }

  Future<void> excluir(Evento ev) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text('Excluir o evento "${ev.nome}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deletarEvento(ev.id!);
      carregar();
    } catch (e) {
      mostrarErro(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos locais'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: carregar),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: abrirForm,
        child: const Icon(Icons.add),
      ),
      body: montarLista(),
    );
  }

  Widget montarLista() {
    if (carregando) return const Center(child: CircularProgressIndicator());
    if (lista.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Nenhum evento cadastrado.'),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80), // espaco pro botao
      itemCount: lista.length,
      itemBuilder: (_, i) {
        final ev = lista[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(ev.nome),
            subtitle: Text(
              '${ev.dataInicio} até ${ev.dataFim}  •  impacto: ${ev.impactoPercentual}%',
            ),
            // so admin exclui
            trailing: Sessao.ehAdmin
                ? IconButton(
                    tooltip: 'Excluir',
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => excluir(ev),
                  )
                : null,
          ),
        );
      },
    );
  }
}
