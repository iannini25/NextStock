import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstock/screens/integracao_erp_screen.dart';

import 'apoio/api_falsa.dart';
import 'apoio/sessao.dart';
import 'apoio/tela.dart';
import 'integracao_erp_screen_test.dart' show apiCom, configJson, sincJson;

void main() {
  setUp(() {
    prepararSessao();
    logarComo(perfil: 'admin');
  });

  Future<void> abrir(WidgetTester tester) async {
    usarTelaAlta(tester, altura: 2400);
    await tester.pumpWidget(const MaterialApp(home: IntegracaoErpScreen()));
    await tester.pumpAndSettle();
  }

  ButtonStyleButton botao(WidgetTester tester, String texto) =>
      tester.widget<ButtonStyleButton>(find.ancestor(of: find.text(texto), matching: find.bySubtype<ButtonStyleButton>()));

  testWidgets('sem chave salva, testar e sincronizar ficam desligados', (tester) async {
    final api = apiCom({'/erp/configuracao': (_) => respostaJson(configJson(configurado: false, comChave: false))});
    await api.usar(() => abrir(tester));

    expect(botao(tester, 'Testar conexão').onPressed, isNull);
    expect(botao(tester, 'Sincronizar agora').onPressed, isNull);
    expect(find.text('Salve a URL e a chave do ERP pra poder testar e sincronizar.'), findsOneWidget);
    expect(find.text('Nenhuma sincronização ainda.'), findsOneWidget);
  });

  testWidgets('testar conexão mostra o resultado', (tester) async {
    final api = apiCom({
      '/erp/configuracao': (_) => respostaJson(configJson()),
      '/erp/testar-conexao': (_) => respostaJson({'ok': true, 'mensagem': 'Conexão com o ERP funcionando'}),
    });

    await api.usar(() async {
      await abrir(tester);
      await tester.tap(find.text('Testar conexão'));
      await tester.pumpAndSettle();
    });

    expect(api.chamadas('/erp/testar-conexao').single.method, 'POST');
    expect(find.text('Conexão com o ERP funcionando'), findsOneWidget);
  });

  testWidgets('falha no teste de conexão aparece em vermelho', (tester) async {
    final api = apiCom({
      '/erp/configuracao': (_) => respostaJson(configJson()),
      '/erp/testar-conexao': (_) => respostaJson(
          {'erro': 'o ERP recusou a chave da API (HTTP 401): confira a chave cadastrada'}, status: 502),
    });

    await api.usar(() async {
      await abrir(tester);
      await tester.tap(find.text('Testar conexão'));
      await tester.pumpAndSettle();
    });

    expect(find.widgetWithText(SnackBar, 'o ERP recusou a chave da API (HTTP 401): confira a chave cadastrada'),
        findsOneWidget);
  });

  testWidgets('sincronizar mostra o resumo e atualiza o histórico', (tester) async {
    var sincronizou = false;
    final api = apiCom({
      '/erp/configuracao': (_) => respostaJson(configJson()),
      '/erp/sincronizar': (_) {
        sincronizou = true;
        return respostaJson(sincJson(repetidas: 4));
      },
      '/erp/sincronizacoes': (_) => respostaJson(sincronizou ? [sincJson(repetidas: 4)] : []),
    });

    await api.usar(() async {
      await abrir(tester);
      await tester.tap(find.text('Sincronizar agora'));
      await tester.pumpAndSettle();
    });

    expect(find.textContaining('Sincronização: sucesso'), findsOneWidget);
    expect(api.chamadas('/erp/sincronizacoes'), hasLength(2)); // carregou de novo depois de sincronizar
    expect(find.text('16/10/2026 14:30  •  Sucesso'), findsOneWidget);
    expect(
      find.text('2 produto(s) criado(s), 1 atualizado(s), 10 venda(s) importada(s) (4 já tinham vindo antes)'),
      findsWidgets,
    );
    expect(find.text('por Ana'), findsOneWidget);
  });

  testWidgets('falha na sincronização avisa e aparece no histórico', (tester) async {
    const falha = 'não foi possível conectar ao ERP em http://127.0.0.1:5001 (ConnectionRefusedError). Ele está no ar?';
    var tentou = false;
    final api = apiCom({
      '/erp/configuracao': (_) => respostaJson(configJson()),
      '/erp/sincronizar': (_) {
        tentou = true;
        return respostaJson({'erro': falha}, status: 502);
      },
      '/erp/sincronizacoes': (_) =>
          respostaJson(tentou ? [sincJson(status: 'erro', criados: 0, atualizados: 0, vendas: 0, erros: [falha])] : []),
    });

    await api.usar(() async {
      await abrir(tester);
      await tester.tap(find.text('Sincronizar agora'));
      await tester.pumpAndSettle();
    });

    expect(find.widgetWithText(SnackBar, falha), findsOneWidget);
    expect(find.text('16/10/2026 14:30  •  Falhou'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);
  });

  testWidgets('histórico mostra até 3 erros e avisa quantos sobraram', (tester) async {
    final erros = List.generate(5, (i) => 'venda V$i: produto não encontrado');
    final api = apiCom({
      '/erp/configuracao': (_) => respostaJson(configJson()),
      '/erp/sincronizacoes': (_) => respostaJson([sincJson(status: 'parcial', erros: erros)]),
    });

    await api.usar(() => abrir(tester));

    expect(find.text('16/10/2026 14:30  •  Concluída com erros'), findsOneWidget);
    expect(find.text('venda V0: produto não encontrado'), findsOneWidget);
    expect(find.text('venda V2: produto não encontrado'), findsOneWidget);
    expect(find.text('venda V3: produto não encontrado'), findsNothing);
    expect(find.text('e mais 2 erro(s)'), findsOneWidget);
  });
}
