import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/importacao.dart';
import '../services/api_service.dart';
import '../services/salvar_arquivo.dart';

const Map<String, Map<String, String>> modulos = {
  'categorias': {
    'label': 'Categorias',
    'colunas': 'nome, descricao',
    'obrigatorias': 'nome',
    'dica': 'Só esses campos existem no cadastro de categorias.',
  },
  'produtos': {
    'label': 'Produtos',
    'colunas':
        'nome, id_categoria, codigo_barras, preco_custo, preco_venda, quantidade_estoque, estoque_minimo, unidade, data_validade',
    'obrigatorias': 'nome, preco_venda',
    'dica':
        'id_categoria é o número da categoria já cadastrada. Se o código de barras já existir, o produto é atualizado. Prefira o código de barras como texto na planilha.',
  },
  'vendas': {
    'label': 'Vendas',
    'colunas': 'id_produto, quantidade, data_venda',
    'obrigatorias': 'id_produto, quantidade',
    'dica':
        'id_produto é o número do produto já cadastrado. Datas no formato aaaa-mm-dd. Cada venda baixa o estoque, igual registrar na tela de vendas.',
  },
  'eventos': {
    'label': 'Eventos',
    'colunas': 'nome, data_inicio, data_fim, impacto_percentual',
    'obrigatorias': 'nome, data_inicio, data_fim',
    'dica': 'Datas no formato aaaa-mm-dd. impacto_percentual é opcional.',
  },
};

class ImportarErpScreen extends StatefulWidget {
  const ImportarErpScreen({super.key});

  @override
  State<ImportarErpScreen> createState() => _ImportarErpScreenState();
}

class _ImportarErpScreenState extends State<ImportarErpScreen> {
  String modulo = 'produtos';
  String? nomeArquivo;
  List<int>? bytesArquivo;
  ResultadoImportacao? resultado;
  bool importando = false;
  bool baixando = false;

  Map<String, String> get info => modulos[modulo]!;

  void mostrarErro(Object e) {
    if (!mounted) return;
    final msg = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> baixarModelo() async {
    setState(() => baixando = true);
    try {
      final bytes = await ApiService.baixarModelo(modulo);
      if (bytes.length < 2 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
        throw Exception('a API não devolveu a planilha. veja se o proxy está no ar');
      }
      await salvarArquivo('modelo_$modulo.xlsx', bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modelo baixado')),
      );
    } catch (e) {
      mostrarErro(e);
    }
    if (mounted) setState(() => baixando = false);
  }

  Future<void> escolherArquivo() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    if (f.bytes == null) {
      mostrarErro(Exception('não foi possível ler o arquivo'));
      return;
    }
    setState(() {
      nomeArquivo = f.name;
      bytesArquivo = f.bytes;
      resultado = null;
    });
  }

  Future<void> importar() async {
    if (bytesArquivo == null || nomeArquivo == null) {
      mostrarErro(Exception('escolha um arquivo .csv ou .xlsx'));
      return;
    }
    setState(() => importando = true);
    try {
      final r = await ApiService.importarPlanilha(modulo, nomeArquivo!, bytesArquivo!);
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
      appBar: AppBar(title: const Text('Importar planilha')),
      // no computador o formulario nao estica na tela toda
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'O NextStock só aceita as colunas do modelo. Baixe o arquivo, preencha e envie um CSV ou XLSX. Colunas a mais são ignoradas. A segunda linha do modelo é um exemplo - apague ou substitua.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: modulo,
                decoration: const InputDecoration(
                  labelText: 'Módulo',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final e in modulos.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value['label']!)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    modulo = v;
                    resultado = null;
                    nomeArquivo = null;
                    bytesArquivo = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              // informacoes do modulo escolhido num card
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Colunas: ${info['colunas']}'),
                      const SizedBox(height: 4),
                      Text('Obrigatórias: ${info['obrigatorias']}'),
                      const SizedBox(height: 4),
                      Text(info['dica']!),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // os dois primeiros botoes sao de apoio, o principal e o Importar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: baixando ? null : baixarModelo,
                      child: Text(baixando ? 'Baixando...' : 'Baixar modelo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: escolherArquivo,
                      child: const Text('Escolher arquivo'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(nomeArquivo == null ? 'Nenhum arquivo selecionado' : 'Arquivo: $nomeArquivo'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: importando ? null : importar,
                child: Text(importando ? 'Importando...' : 'Importar'),
              ),
              const SizedBox(height: 16),
              if (resultado != null) montarResultado(),
            ],
          ),
        ),
      ),
    );
  }

  Widget montarResultado() {
    final r = resultado!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'importados: ${r.importados}  •  ignorados: ${r.ignorados}',
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
