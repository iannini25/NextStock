import 'package:flutter/material.dart';
import '../models/previsao.dart';
import '../services/api_service.dart';

class PrevisaoScreen extends StatefulWidget {
  const PrevisaoScreen({super.key});

  @override
  State<PrevisaoScreen> createState() => _PrevisaoScreenState();
}

class _PrevisaoScreenState extends State<PrevisaoScreen> {
  int dias = 7;
  String clima = 'normal';
  List<Previsao> lista = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final r = await ApiService.preverDemanda(dias, clima);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Previsão de demanda'),
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
          const Text('Dias:'),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: dias,
            items: const [7, 15, 30]
                .map((d) => DropdownMenuItem(value: d, child: Text('$d dias')))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => dias = v);
              carregar();
            },
          ),
          const SizedBox(width: 16),
          const Text('Clima:'),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: clima,
            items: const [
              DropdownMenuItem(value: 'normal', child: Text('Normal')),
              DropdownMenuItem(value: 'calor', child: Text('Calor')),
              DropdownMenuItem(value: 'frio', child: Text('Frio')),
              DropdownMenuItem(value: 'chuva', child: Text('Chuva')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => clima = v);
              carregar();
            },
          ),
        ],
      ),
    );
  }

  Widget montarLista() {
    if (carregando) return const Center(child: CircularProgressIndicator());
    if (lista.isEmpty) {
      return const Center(child: Text('Nenhuma previsão disponível.'));
    }
    return ListView.builder(
      itemCount: lista.length,
      itemBuilder: (_, i) {
        final p = lista[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: p.previsaoDemanda > p.estoqueAtual
                ? const Icon(Icons.warning_amber, color: Colors.red)
                : const Icon(Icons.check, color: Colors.green),
            title: Text(p.produtoNome),
            subtitle: Text(textoPrevisao(p)),
          ),
        );
      },
    );
  }

  String textoPrevisao(Previsao p) {
    var texto = 'previsão: ${p.previsaoDemanda} ${p.unidade ?? ""} em $dias dias  •  '
        'média: ${p.mediaDiaria.toStringAsFixed(1)}/dia  •  estoque: ${p.estoqueAtual}';
    if (p.diasComEvento > 0) {
      texto += '  •  evento em ${p.diasComEvento} dia(s)';
    }
    return texto;
  }
}
