import 'produto.dart';

class ItemConsumo {
  int idProduto;
  String produtoNome;
  String? categoriaNome;
  int quantidadeVendida;
  double faturamento;
  double percentualDoTotal;

  ItemConsumo({
    required this.idProduto,
    required this.produtoNome,
    this.categoriaNome,
    required this.quantidadeVendida,
    required this.faturamento,
    required this.percentualDoTotal,
  });

  factory ItemConsumo.fromJson(Map<String, dynamic> j) {
    return ItemConsumo(
      idProduto: j['id_produto'] ?? 0,
      produtoNome: j['produto_nome'] ?? '',
      categoriaNome: j['categoria_nome'],
      quantidadeVendida: j['quantidade_vendida'] ?? 0,
      faturamento: paraDouble(j['faturamento']) ?? 0,
      percentualDoTotal: paraDouble(j['percentual_do_total']) ?? 0,
    );
  }
}

class RelatorioConsumo {
  int dias;
  int totalVendido;
  double faturamentoTotal;
  List<ItemConsumo> itens;

  RelatorioConsumo({
    required this.dias,
    required this.totalVendido,
    required this.faturamentoTotal,
    required this.itens,
  });

  factory RelatorioConsumo.fromJson(Map<String, dynamic> j) {
    return RelatorioConsumo(
      dias: j['dias'] ?? 0,
      totalVendido: j['total_vendido'] ?? 0,
      faturamentoTotal: paraDouble(j['faturamento_total']) ?? 0,
      itens: (j['itens'] as List? ?? []).map((e) => ItemConsumo.fromJson(e)).toList(),
    );
  }
}

class ItemDesempenho {
  int idProduto;
  String produtoNome;
  int quantidadeVendida;
  double faturamento;

  ItemDesempenho({
    required this.idProduto,
    required this.produtoNome,
    required this.quantidadeVendida,
    required this.faturamento,
  });

  factory ItemDesempenho.fromJson(Map<String, dynamic> j) {
    return ItemDesempenho(
      idProduto: j['id_produto'] ?? 0,
      produtoNome: j['produto_nome'] ?? '',
      quantidadeVendida: j['quantidade_vendida'] ?? 0,
      faturamento: paraDouble(j['faturamento']) ?? 0,
    );
  }
}

class ItemMargem {
  int idProduto;
  String produtoNome;
  double? precoCusto;
  double? precoVenda;
  double margemPercentual;

  ItemMargem({
    required this.idProduto,
    required this.produtoNome,
    this.precoCusto,
    this.precoVenda,
    required this.margemPercentual,
  });

  factory ItemMargem.fromJson(Map<String, dynamic> j) {
    return ItemMargem(
      idProduto: j['id_produto'] ?? 0,
      produtoNome: j['produto_nome'] ?? '',
      precoCusto: paraDouble(j['preco_custo']),
      precoVenda: paraDouble(j['preco_venda']),
      margemPercentual: paraDouble(j['margem_percentual']) ?? 0,
    );
  }
}

class RelatorioDesempenho {
  List<ItemDesempenho> maisVendidos;
  List<ItemDesempenho> menosVendidos;
  List<ItemMargem> margens;

  RelatorioDesempenho({
    required this.maisVendidos,
    required this.menosVendidos,
    required this.margens,
  });

  factory RelatorioDesempenho.fromJson(Map<String, dynamic> j) {
    return RelatorioDesempenho(
      maisVendidos: (j['mais_vendidos'] as List? ?? []).map((e) => ItemDesempenho.fromJson(e)).toList(),
      menosVendidos: (j['menos_vendidos'] as List? ?? []).map((e) => ItemDesempenho.fromJson(e)).toList(),
      margens: (j['margens'] as List? ?? []).map((e) => ItemMargem.fromJson(e)).toList(),
    );
  }
}

class Tendencia {
  int idProduto;
  String produtoNome;
  int vendasPeriodoAnterior;
  int vendasPeriodoAtual;
  double variacaoPercentual;
  String tendencia;

  Tendencia({
    required this.idProduto,
    required this.produtoNome,
    required this.vendasPeriodoAnterior,
    required this.vendasPeriodoAtual,
    required this.variacaoPercentual,
    required this.tendencia,
  });

  factory Tendencia.fromJson(Map<String, dynamic> j) {
    return Tendencia(
      idProduto: j['id_produto'] ?? 0,
      produtoNome: j['produto_nome'] ?? '',
      vendasPeriodoAnterior: j['vendas_periodo_anterior'] ?? 0,
      vendasPeriodoAtual: j['vendas_periodo_atual'] ?? 0,
      variacaoPercentual: paraDouble(j['variacao_percentual']) ?? 0,
      tendencia: j['tendencia'] ?? '',
    );
  }
}
