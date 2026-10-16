import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// resposta JSON em UTF-8, igual a API manda (o ApiService decodifica os bytes como UTF-8)
http.Response respostaJson(Object? corpo, {int status = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(corpo)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

// API falsa pros testes de tela: cada rota (caminho sem a query) devolve uma resposta.
// rota nao prevista responde 404 e toda requisicao fica guardada em [requisicoes].
class ApiFalsa {
  final Map<String, http.Response Function(http.Request)> rotas;
  final List<http.Request> requisicoes = [];

  ApiFalsa(this.rotas);

  late final MockClient cliente = MockClient((req) async {
    requisicoes.add(req);
    final rota = rotas[req.url.path];
    if (rota == null) {
      return respostaJson({'erro': 'rota não prevista no teste: ${req.url.path}'}, status: 404);
    }
    return rota(req);
  });

  // roda [corpo] com o pacote http apontando pra essa API falsa, sem rede e sem mexer no ApiService.
  // tudo que dispara requisicao (abrir a tela, tocar em botao) precisa acontecer aqui dentro.
  Future<T> usar<T>(Future<T> Function() corpo) => http.runWithClient(corpo, () => cliente);

  // requisicoes feitas pra um caminho
  List<http.Request> chamadas(String caminho) =>
      requisicoes.where((r) => r.url.path == caminho).toList();
}
