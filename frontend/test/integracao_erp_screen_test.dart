import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nextstock/screens/integracao_erp_screen.dart';

import 'apoio/api_falsa.dart';
import 'apoio/sessao.dart';
import 'apoio/tela.dart';

Map<String, dynamic> configJson({bool configurado = true, bool comChave = true, String? aviso}) => {
      'configurado': configurado,
      'provedores': {'generico': 'ERP genérico (API REST)'},
      'provedor': 'generico',
      'url_base': configurado ? 'https://erp.loja.com/api' : null,
      'ativo': configurado,
      'possui_chave': comChave,
      'chave_mascarada': comChave ? '••••1a2b' : null,
      'aviso': aviso,
      'atualizado_em': configurado ? '2026-10-16T09:05' : null,
      'atualizado_por': configurado ? 'Ana' : null,
    };

// a tela tambem carrega o historico de sincronizacoes; por padrao ele vem vazio
ApiFalsa apiCom(Map<String, http.Response Function(http.Request)> rotas) {
  return ApiFalsa({'/erp/sincronizacoes': (_) => respostaJson([]), ...rotas});
}

Map<String, dynamic> sincJson({
  int id = 1,
  String status = 'sucesso',
  int criados = 2,
  int atualizados = 1,
  int vendas = 10,
  int repetidas = 0,
  List<String> erros = const [],
}) =>
    {
      'id_sincronizacao': id,
      'iniciado_em': '2026-10-16T14:30:00',
      'finalizado_em': '2026-10-16T14:30:02',
      'status': status,
      'produtos_criados': criados,
      'produtos_atualizados': atualizados,
      'vendas_importadas': vendas,
      'vendas_ja_importadas': repetidas,
      'erros': erros,
      'usuario': 'Ana',
    };

const rotuloChaveNova = 'Chave da API *';
const rotuloTrocarChave = 'Nova chave da API (em branco = manter a atual)';

void main() {
  setUp(() {
    prepararSessao();
    logarComo(perfil: 'admin');
  });

  Future<void> abrir(WidgetTester tester) async {
    usarTelaAlta(tester);
    await tester.pumpWidget(const MaterialApp(home: IntegracaoErpScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('primeira configuração: manda URL e chave e mostra a chave mascarada', (tester) async {
    Map<String, dynamic>? enviado;
    final api = apiCom({
      '/erp/configuracao': (req) {
        if (req.method == 'PUT') {
          enviado = jsonDecode(req.body) as Map<String, dynamic>;
          return respostaJson(configJson());
        }
        return respostaJson(configJson(configurado: false, comChave: false));
      },
    });

    await api.usar(() async {
      await abrir(tester);
      expect(find.text('Nenhuma chave cadastrada.'), findsOneWidget);
      await preencher(tester, 'URL da API do ERP *', 'https://erp.loja.com/api');
      await preencher(tester, rotuloChaveNova, 'segredo-1a2b');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    });

    expect(enviado, {
      'provedor': 'generico',
      'url_base': 'https://erp.loja.com/api',
      'chave_api': 'segredo-1a2b',
      'ativo': true,
    });
    expect(find.text('Chave salva: ••••1a2b'), findsOneWidget);
    expect(find.text('Última alteração: 16/10/2026 09:05 por Ana'), findsOneWidget);
    expect(find.text('Configuração do ERP salva'), findsOneWidget);
    // depois de salvar, a chave digitada some da tela
    expect(find.text('segredo-1a2b'), findsNothing);
    expect(find.widgetWithText(TextField, rotuloTrocarChave), findsOneWidget);
  });

  testWidgets('a chave digitada fica escondida até tocar no olho', (tester) async {
    final api = apiCom({'/erp/configuracao': (_) => respostaJson(configJson(configurado: false, comChave: false))});

    await api.usar(() async {
      await abrir(tester);
      TextField campoChave() => tester.widget<TextField>(find.widgetWithText(TextField, rotuloChaveNova));
      expect(campoChave().obscureText, isTrue);
      await tester.tap(find.byTooltip('Mostrar chave'));
      await tester.pump();
      expect(campoChave().obscureText, isFalse);
    });
  });

  testWidgets('sem chave salva, salvar sem digitar a chave é barrado no app', (tester) async {
    final api = apiCom({'/erp/configuracao': (_) => respostaJson(configJson(configurado: false, comChave: false))});

    await api.usar(() async {
      await abrir(tester);
      await preencher(tester, 'URL da API do ERP *', 'https://erp.loja.com/api');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    });

    expect(find.widgetWithText(SnackBar, 'informe a chave da API do ERP'), findsOneWidget);
    expect(api.requisicoes.where((r) => r.method == 'PUT'), isEmpty);
  });

  testWidgets('com chave salva, trocar só a URL manda a chave em branco (mantém a atual)', (tester) async {
    Map<String, dynamic>? enviado;
    final api = apiCom({
      '/erp/configuracao': (req) {
        if (req.method == 'PUT') enviado = jsonDecode(req.body) as Map<String, dynamic>;
        return respostaJson(configJson());
      },
    });

    await api.usar(() async {
      await abrir(tester);
      expect(find.text('https://erp.loja.com/api'), findsOneWidget);
      await preencher(tester, 'URL da API do ERP *', 'https://erp2.loja.com');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    });

    expect(enviado!['url_base'], 'https://erp2.loja.com');
    expect(enviado!['chave_api'], '');
  });

  testWidgets('remover chave pede confirmação e chama a API', (tester) async {
    final api = apiCom({
      '/erp/configuracao': (_) => respostaJson(configJson()),
      '/erp/configuracao/chave': (_) => respostaJson(configJson(comChave: false)),
    });

    await api.usar(() async {
      await abrir(tester);
      await tester.tap(find.text('Remover chave'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sim'));
      await tester.pumpAndSettle();
    });

    expect(api.chamadas('/erp/configuracao/chave').single.method, 'DELETE');
    expect(find.text('Nenhuma chave cadastrada.'), findsOneWidget);
    expect(find.text('Remover chave'), findsNothing);
  });

  testWidgets('erro da API (ex.: falta a chave de criptografia no servidor) aparece', (tester) async {
    final api = apiCom({
      '/erp/configuracao': (req) => req.method == 'PUT'
          ? respostaJson({'erro': 'configure a ERP_CHAVE_CRIPTOGRAFIA no .env da API'}, status: 500)
          : respostaJson(configJson(configurado: false, comChave: false)),
    });

    await api.usar(() async {
      await abrir(tester);
      await preencher(tester, 'URL da API do ERP *', 'https://erp.loja.com/api');
      await preencher(tester, rotuloChaveNova, 'segredo');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    });

    expect(find.widgetWithText(SnackBar, 'configure a ERP_CHAVE_CRIPTOGRAFIA no .env da API'), findsOneWidget);
  });

  testWidgets('aviso da API (chave que não abre mais) aparece na situação', (tester) async {
    final api = apiCom({
      '/erp/configuracao': (_) => respostaJson({
            ...configJson(),
            'chave_mascarada': null,
            'aviso': 'a chave salva não abre com a ERP_CHAVE_CRIPTOGRAFIA atual. Cadastre a chave de novo.',
          }),
    });

    await api.usar(() => abrir(tester));

    expect(find.text('Chave salva: (não foi possível ler)'), findsOneWidget);
    expect(find.textContaining('Cadastre a chave de novo'), findsOneWidget);
  });
}
