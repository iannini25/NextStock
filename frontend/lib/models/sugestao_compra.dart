import 'produto.dart';

class SugestaoCompra {
  int idProduto;
  String produtoNome;
  String? unidade;
  int estoqueAtual;
  int estoqueMinimo;
  int previsaoDemanda;
  int quantidadeSugerida;
  double? precoCusto;
  double custoEstimado;

  SugestaoCompra({
    required this.idProduto,
    required this.produtoNome,
    this.unidade,
    required this.estoqueAtual,
    required this.estoqueMinimo,
    required this.previsaoDemanda,
    required this.quantidadeSugerida,
    this.precoCusto,
    required this.custoEstimado,
  });

  factory SugestaoCompra.fromJson(Map<String, dynamic> j) {
    return SugestaoCompra(
      idProduto: j['id_produto'] ?? 0,
      produtoNome: j['produto_nome'] ?? '',
      unidade: j['unidade'],
      estoqueAtual: j['estoque_atual'] ?? 0,
      estoqueMinimo: j['estoque_minimo'] ?? 0,
      previsaoDemanda: j['previsao_demanda'] ?? 0,
      quantidadeSugerida: j['quantidade_sugerida'] ?? 0,
      precoCusto: paraDouble(j['preco_custo']),
      custoEstimado: paraDouble(j['custo_estimado']) ?? 0,
    );
  }
}
