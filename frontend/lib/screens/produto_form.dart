import 'package:flutter/material.dart';
import '../models/produto.dart';
import '../models/categoria.dart';
import '../services/api_service.dart';

class ProdutoForm extends StatefulWidget {
  final Produto? produto;
  const ProdutoForm({super.key, this.produto});

  @override
  State<ProdutoForm> createState() => _ProdutoFormState();
}

class _ProdutoFormState extends State<ProdutoForm> {
  final nome = TextEditingController();
  final codigo = TextEditingController();
  final custo = TextEditingController();
  final venda = TextEditingController();
  final qtd = TextEditingController();
  final unidade = TextEditingController(text: 'UN');
  final validade = TextEditingController();

  List<Categoria> categorias = [];
  int? categoriaId;
  bool carregouCategorias = false;
  bool salvando = false;

  @override
  void initState() {
    super.initState();
    final p = widget.produto;
    if (p != null) {
      // edicao: joga os dados nos campos
      nome.text = p.nome;
      codigo.text = p.codigoBarras ?? '';
      custo.text = p.precoCusto?.toString() ?? '';
      venda.text = p.precoVenda?.toString() ?? '';
      qtd.text = p.quantidade?.toString() ?? '';
      unidade.text = p.unidade ?? 'UN';
      validade.text = p.validade ?? '';
      categoriaId = p.idCategoria;
    }
    carregarCategorias();
  }

  Future<void> carregarCategorias() async {
    try {
      final lista = await ApiService.listarCategorias();
      if (!mounted) return;
      setState(() {
        categorias = lista;
        carregouCategorias = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => carregouCategorias = true);
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

  Future<void> salvar() async {
    setState(() => salvando = true);
    // monta o produto com o que foi digitado
    final p = Produto(
      nome: nome.text,
      idCategoria: categoriaId,
      codigoBarras: codigo.text.isEmpty ? null : codigo.text,
      precoCusto: double.tryParse(custo.text.replaceAll(',', '.')),
      precoVenda: double.tryParse(venda.text.replaceAll(',', '.')),
      quantidade: int.tryParse(qtd.text),
      unidade: unidade.text.isEmpty ? 'UN' : unidade.text,
      validade: validade.text.isEmpty ? null : validade.text,
    );
    try {
      if (widget.produto == null) {
        await ApiService.criarProduto(p);
      } else {
        await ApiService.atualizarProduto(widget.produto!.id!, p);
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
    final editando = widget.produto != null;
    return Scaffold(
      appBar: AppBar(title: Text(editando ? 'Editar produto' : 'Novo produto')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          campo(nome, 'Nome *'),
          montarDropdown(),
          campo(codigo, 'Código de barras'),
          campo(custo, 'Preço de custo', numero: true),
          campo(venda, 'Preço de venda *', numero: true),
          campo(qtd, 'Quantidade em estoque', numero: true),
          campo(unidade, 'Unidade'),
          campo(validade, 'Validade (aaaa-mm-dd)'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: salvando ? null : salvar,
            child: Text(salvando ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
    );
  }

  // dropdown das categorias (carregado da api)
  Widget montarDropdown() {
    if (!carregouCategorias) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: LinearProgressIndicator(),
      );
    }
    // se a categoria do produto nao existe mais, fica "sem categoria"
    final valor = categorias.any((c) => c.id == categoriaId) ? categoriaId : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int?>(
        initialValue: valor,
        decoration: const InputDecoration(
            labelText: 'Categoria', border: OutlineInputBorder()),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('Sem categoria')),
          ...categorias.map(
              (c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.nome))),
        ],
        onChanged: (v) => categoriaId = v,
      ),
    );
  }

  // ajuda a montar cada campo de texto
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
