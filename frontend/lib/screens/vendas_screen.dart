import 'package:flutter/material.dart';
import '../models/venda.dart';
import '../services/api_service.dart';
import 'venda_form.dart';

class VendasScreen extends StatefulWidget {
  const VendasScreen({super.key});

  @override
  State<VendasScreen> createState() => _VendasScreenState();
}

class _VendasScreenState extends State<VendasScreen> {
  int dias = 30;
  List<Venda> lista = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final r = await ApiService.listarVendas(dias);
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
      MaterialPageRoute(builder: (_) => const VendaForm()),
    );
    if (salvou == true) carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendas'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: carregar),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: abrirForm,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          montarFiltroDias(),
          Expanded(child: montarLista()),
        ],
      ),
    );
  }

  Widget montarFiltroDias() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          const Text('Vendas dos últimos:'),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: dias,
            items: const [7, 15, 30, 60]
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

  Widget montarLista() {
    if (carregando) return const Center(child: CircularProgressIndicator());
    if (lista.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.point_of_sale, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Nenhuma venda nesse período.'),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80), // espaco pro botao
      itemCount: lista.length,
      itemBuilder: (_, i) {
        final v = lista[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(v.produtoNome ?? 'produto ${v.idProduto}'),
            subtitle: Text(
              'quantidade: ${v.quantidade}  •  R\$ ${v.valorTotal?.toStringAsFixed(2) ?? "-"}  •  ${v.dataVenda ?? "-"}',
            ),
          ),
        );
      },
    );
  }
}
