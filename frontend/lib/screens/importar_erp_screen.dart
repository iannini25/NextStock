import 'package:flutter/material.dart';
import '../models/importacao.dart';
import '../services/api_service.dart';

const String exemploJson = '''{
  "produtos": [
    {
      "codigo_barras": "7890000000062",
      "nome": "Queijo Minas 500g",
      "categoria": "Laticínios",
      "preco_custo": 12.0,
      "preco_venda": 19.9,
      "quantidade_estoque": 20,
      "estoque_minimo": 5,
      "unidade": "UN",
      "data_validade": "2026-09-10"
    }
  ],
  "vendas": [
    {
      "codigo_barras": "7890000000024",
      "quantidade": 3,
      "data_venda": "2026-08-20"
    }
  ]
}''';

class ImportarErpScreen extends StatefulWidget {
  const ImportarErpScreen({super.key});

  @override
  State<ImportarErpScreen> createState() => _ImportarErpScreenState();
}

class _ImportarErpScreenState extends State<ImportarErpScreen> {
  final texto = TextEditingController();
  ResultadoImportacao? resultado;
  bool importando = false;

  void mostrarErro(Object e) {
    if (!mounted) return;
    final msg = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void usarExemplo() {
    setState(() => texto.text = exemploJson);
  }

  Future<void> importar() async {
    setState(() => importando = true);
    try {
      final r = await ApiService.importarErp(texto.text);
      if (!mounted) return;
      setState(() {
        resultado = r;
        importando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => importando = false);
      mostrarErro(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar do ERP')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Cole o JSON exportado do ERP com "produtos" e "vendas".'),
          const SizedBox(height: 12),
          TextField(
            controller: texto,
            maxLines: 12,
            decoration: const InputDecoration(
                labelText: 'JSON', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: usarExemplo,
                  child: const Text('Usar exemplo'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: importando ? null : importar,
                  child: Text(importando ? 'Importando...' : 'Importar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (resultado != null) montarResultado(),
        ],
      ),
    );
  }

  Widget montarResultado() {
    final r = resultado!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'criados: ${r.produtosCriados}  •  atualizados: ${r.produtosAtualizados}  •  vendas: ${r.vendasImportadas}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final erro in r.erros)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(erro, style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}
