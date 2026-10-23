import 'package:flutter/material.dart';
import '../models/sugestao_compra.dart';
import '../services/api_service.dart';

class ComprasScreen extends StatefulWidget {
  const ComprasScreen({super.key});

  @override
  State<ComprasScreen> createState() => _ComprasScreenState();
}

class _ComprasScreenState extends State<ComprasScreen> {
  int dias = 7;
  String clima = 'auto';
  List<SugestaoCompra> lista = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final r = await ApiService.sugerirCompras(dias, clima);
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
        title: const Text('Sugestão de compras'),
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
              DropdownMenuItem(value: 'auto', child: Text('Automático')),
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

  double calcularTotal() {
    double total = 0;
    for (final s in lista) {
      total += s.custoEstimado;
    }
    return total;
  }

  Widget montarLista() {
    if (carregando) return const Center(child: CircularProgressIndicator());
    if (lista.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Nenhuma compra sugerida.'),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // resumo no topo, igual ao da tela de perdas
        Card(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Total estimado: R\$ ${calcularTotal().toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: lista.length,
            itemBuilder: (_, i) {
              final s = lista[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(s.produtoNome),
                  subtitle: Text(
                    'comprar: ${s.quantidadeSugerida} ${s.unidade ?? ""}  •  '
                    'estoque: ${s.estoqueAtual} (mín: ${s.estoqueMinimo})  •  '
                    'previsão: ${s.previsaoDemanda}',
                  ),
                  trailing: Text(
                    'R\$ ${s.custoEstimado.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
