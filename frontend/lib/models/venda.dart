import 'produto.dart';

class Venda {
  int? id;
  int idProduto;
  String? produtoNome;
  int quantidade;
  double? valorTotal;
  String? dataVenda;

  Venda({
    this.id,
    required this.idProduto,
    this.produtoNome,
    required this.quantidade,
    this.valorTotal,
    this.dataVenda,
  });

  factory Venda.fromJson(Map<String, dynamic> j) {
    return Venda(
      id: j['id_venda'],
      idProduto: j['id_produto'] ?? 0,
      produtoNome: j['produto_nome'],
      quantidade: j['quantidade'] ?? 0,
      valorTotal: paraDouble(j['valor_total']),
      dataVenda: j['data_venda'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_produto': idProduto,
      'quantidade': quantidade,
      'data_venda': dataVenda,
    };
  }
}
