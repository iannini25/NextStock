import 'produto.dart';

class Painel {
  int totalProdutos;
  int itensEmEstoque;
  double valorEstoque;
  int produtosVencidos;
  double valorVencido;
  int produtosVencendo;
  int produtosEmRisco;
  int vendas30Dias;
  double faturamento30Dias;
  double percentualDesperdicio;
  double giroEstoque;

  Painel({
    required this.totalProdutos,
    required this.itensEmEstoque,
    required this.valorEstoque,
    required this.produtosVencidos,
    required this.valorVencido,
    required this.produtosVencendo,
    required this.produtosEmRisco,
    required this.vendas30Dias,
    required this.faturamento30Dias,
    required this.percentualDesperdicio,
    required this.giroEstoque,
  });

  factory Painel.fromJson(Map<String, dynamic> j) {
    return Painel(
      totalProdutos: j['total_produtos'] ?? 0,
      itensEmEstoque: j['itens_em_estoque'] ?? 0,
      valorEstoque: paraDouble(j['valor_estoque']) ?? 0,
      produtosVencidos: j['produtos_vencidos'] ?? 0,
      valorVencido: paraDouble(j['valor_vencido']) ?? 0,
      produtosVencendo: j['produtos_vencendo'] ?? 0,
      produtosEmRisco: j['produtos_em_risco'] ?? 0,
      vendas30Dias: j['vendas_30_dias'] ?? 0,
      faturamento30Dias: paraDouble(j['faturamento_30_dias']) ?? 0,
      percentualDesperdicio: paraDouble(j['percentual_desperdicio']) ?? 0,
      giroEstoque: paraDouble(j['giro_estoque']) ?? 0,
    );
  }
}
