// data aaaa-mm-dd relativa a hoje: dataDaqui(-1) = ontem
String dataDaqui(int dias) {
  final d = DateTime.now().add(Duration(days: dias));
  final mes = d.month.toString().padLeft(2, '0');
  final dia = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mes-$dia';
}

// produto no formato que a API devolve
Map<String, dynamic> produtoJson({
  required int id,
  required String nome,
  String? categoria,
  int quantidade = 10,
  int minimo = 2,
  double precoVenda = 5.0,
  String? validade,
  String? motivo,
}) {
  return {
    'id_produto': id,
    'id_categoria': categoria == null ? null : 1,
    'categoria_nome': categoria,
    'nome': nome,
    'codigo_barras': null,
    'preco_custo': 3.0,
    'preco_venda': precoVenda,
    'quantidade_estoque': quantidade,
    'estoque_minimo': minimo,
    'unidade': 'UN',
    'data_validade': validade,
    'motivo': motivo, // a API so manda motivo na lista de risco
  };
}

Map<String, dynamic> empresaJson({String nome = 'Mercado Bom Preço LTDA', String? fantasia = 'Bom Preço'}) {
  return {
    'id_empresa': 1,
    'nome': nome,
    'nome_fantasia': fantasia,
    'cnpj': '12345678000190',
    'email': 'contato@bompreco.com',
    'telefone': '(11) 99999-0000',
  };
}

Map<String, dynamic> usuarioJson({
  required int id,
  required String nome,
  String? email,
  String perfil = 'usuario',
  bool ativo = true,
}) {
  return {
    'id_usuario': id,
    'id_empresa': 1,
    'nome': nome,
    'email': email ?? '${nome.toLowerCase()}@loja.com',
    'perfil': perfil,
    'ativo': ativo,
  };
}

// resposta do /clima
Map<String, dynamic> climaJson({List<Map<String, dynamic>> dias = const []}) {
  return {
    'cidade': 'Sao Paulo',
    'fonte': dias.isEmpty ? 'nenhum' : 'open-meteo',
    'aviso': null,
    'dias': dias,
  };
}
