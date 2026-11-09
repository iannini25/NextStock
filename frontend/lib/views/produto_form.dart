import 'package:flutter/material.dart';
import '../models/produto.dart';
import '../models/categoria.dart';
import '../models/armazenamento.dart';
import '../services/api_service.dart';
import 'lotes_screen.dart';

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
  final minimo = TextEditingController();
  final unidade = TextEditingController(text: 'UN');
  final validade = TextEditingController();

  List<Categoria> categorias = [];
  int? categoriaId;
  bool carregouCategorias = false;
  bool salvando = false;
  // local de armazenamento (opcional). se a lista nao carregar, o campo some e o local fica como esta
  List<LocalArmazenamento> locais = [];
  int? localId;
  bool carregouLocais = false;

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
      minimo.text = p.estoqueMinimo?.toString() ?? '';
      unidade.text = p.unidade ?? 'UN';
      validade.text = p.validade ?? '';
      categoriaId = p.idCategoria;
      localId = p.idLocal;
    }
    carregarCategorias();
    carregarLocais();
  }

  Future<void> carregarLocais() async {
    try {
      final lista = await ApiService.listarLocais();
      if (!mounted) return;
      setState(() {
        locais = lista;
        carregouLocais = true;
      });
    } catch (_) {
      // sem a lista o formulario funciona igual: so nao mexe no local
    }
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

  // na edicao, quantidade e validade sao dos lotes: abre a tela de lotes e atualiza os campos na volta
  Future<void> gerenciarLotes() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => LotesScreen(produto: widget.produto!)));
    try {
      final atual = await ApiService.buscarProduto(widget.produto!.id!);
      if (!mounted) return;
      setState(() {
        qtd.text = atual.quantidade?.toString() ?? '0';
        validade.text = atual.validade ?? '';
      });
    } catch (e) {
      mostrarErro(e);
    }
  }

  Future<void> salvar() async {
    setState(() => salvando = true);
    final editando = widget.produto != null;
    // monta o produto com o que foi digitado.
    // na edicao nao manda quantidade nem validade: assim a API mantem o estoque dos lotes como esta
    final p = Produto(
      nome: nome.text,
      idCategoria: categoriaId,
      codigoBarras: codigo.text.isEmpty ? null : codigo.text,
      precoCusto: double.tryParse(custo.text.replaceAll(',', '.')),
      precoVenda: double.tryParse(venda.text.replaceAll(',', '.')),
      quantidade: editando ? null : int.tryParse(qtd.text),
      estoqueMinimo: int.tryParse(minimo.text),
      unidade: unidade.text.isEmpty ? 'UN' : unidade.text,
      validade: editando || validade.text.isEmpty ? null : validade.text,
      idLocal: localId,
      enviarLocal: carregouLocais,
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
      // no computador o formulario nao estica na tela toda
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              campo(nome, 'Nome *'),
              montarDropdown(),
              campo(codigo, 'Código de barras'),
              campo(custo, 'Preço de custo', numero: true),
              campo(venda, 'Preço de venda *', numero: true),
              if (editando) ...[
                // com lotes, o estoque e a validade vem das entradas e das vendas
                campo(qtd, 'Quantidade em estoque', numero: true, somenteLeitura: true),
                campo(validade, 'Próxima validade (do lote que vence antes)', somenteLeitura: true),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: gerenciarLotes,
                    icon: const Icon(Icons.inventory),
                    label: const Text('Gerenciar lotes (entradas e validades)'),
                  ),
                ),
              ] else ...[
                campo(qtd, 'Quantidade em estoque', numero: true),
                campo(validade, 'Validade (aaaa-mm-dd)'),
              ],
              campo(minimo, 'Estoque mínimo (pra alertar antes de faltar)', numero: true),
              campo(unidade, 'Unidade'),
              if (carregouLocais) montarDropdownLocal(),
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

  // onde o produto fica guardado. se o local dele foi desativado, continua aparecendo (marcado)
  Widget montarDropdownLocal() {
    final itens = <int?, String>{null: 'Sem local definido', for (final l in locais) l.id: '${l.nome} (${l.faixa})'};
    if (localId != null && !itens.containsKey(localId)) {
      itens[localId] = '${widget.produto?.localNome ?? 'Local #$localId'} (desativado)';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int?>(
        initialValue: localId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Local de armazenamento', border: OutlineInputBorder()),
        items: itens.entries.map((e) => DropdownMenuItem<int?>(value: e.key, child: Text(e.value))).toList(),
        onChanged: (v) => localId = v,
      ),
    );
  }

  // ajuda a montar cada campo de texto
  Widget campo(TextEditingController c, String label, {bool numero = false, bool somenteLeitura = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        readOnly: somenteLeitura,
        enabled: !somenteLeitura,
        keyboardType: numero ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
