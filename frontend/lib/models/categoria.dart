class Categoria {
  int? id;
  String nome;
  String? descricao;

  Categoria({this.id, required this.nome, this.descricao});

  // le o json que veio da api
  factory Categoria.fromJson(Map<String, dynamic> j) {
    return Categoria(
      id: j['id_categoria'],
      nome: j['nome'] ?? '',
      descricao: j['descricao'],
    );
  }

  // vira json pra mandar no post/put
  Map<String, dynamic> toJson() {
    return {'nome': nome, 'descricao': descricao};
  }
}
