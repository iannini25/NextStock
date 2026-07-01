class Produto {
  int? id;
  int? idCategoria;
  String? categoriaNome; // so leitura, ja vem pronto da api
  String nome;
  String? codigoBarras;
  double? precoCusto;
  double? precoVenda;
  int? quantidade;
  String? unidade;
  String? validade; // aaaa-mm-dd

  Produto({
    this.id,
    this.idCategoria,
    this.categoriaNome,
    required this.nome,
    this.codigoBarras,
    this.precoCusto,
    this.precoVenda,
    this.quantidade,
    this.unidade,
    this.validade,
  });

  factory Produto.fromJson(Map<String, dynamic> j) {
    return Produto(
      id: j['id_produto'],
      idCategoria: j['id_categoria'],
      categoriaNome: j['categoria_nome'],
      nome: j['nome'] ?? '',
      codigoBarras: j['codigo_barras'],
      precoCusto: paraDouble(j['preco_custo']),
      precoVenda: paraDouble(j['preco_venda']),
      quantidade: j['quantidade_estoque'],
      unidade: j['unidade'],
      validade: j['data_validade'],
    );
  }

  // nao manda categoria_nome (e so leitura)
  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'id_categoria': idCategoria,
      'codigo_barras': codigoBarras,
      'preco_custo': precoCusto,
      'preco_venda': precoVenda,
      'quantidade_estoque': quantidade,
      'unidade': unidade,
      'data_validade': validade,
    };
  }
}

// o preco pode vir como int ou double, entao converte
double? paraDouble(dynamic v) {
  if (v == null) return null;
  return (v as num).toDouble();
}
