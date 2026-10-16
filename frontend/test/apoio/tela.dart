import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// tela alta pra caber formularios e listas compridas sem precisar rolar
void usarTelaAlta(WidgetTester tester, {double largura = 800, double altura = 1600}) {
  tester.view.physicalSize = Size(largura, altura);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

// digita num campo de texto achado pelo rotulo
Future<void> preencher(WidgetTester tester, String rotulo, String texto) async {
  await tester.enterText(find.widgetWithText(TextField, rotulo), texto);
}
