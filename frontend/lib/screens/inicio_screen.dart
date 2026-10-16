import 'package:flutter/material.dart';
import '../main.dart';
import '../shell/app_shell.dart';

// tela inicial: um painel com os atalhos pros modulos. a marca fica
// na barra de cima da casca (app_shell), entao aqui nao repete.
class InicioScreen extends StatelessWidget {
  // os modulos que quem esta logado pode ver
  final List<ItemNav> modulos;
  // avisa a casca pra trocar o modulo selecionado
  final void Function(String id)? aoAbrir;
  const InicioScreen({super.key, required this.modulos, this.aoAbrir});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricoes) {
        final largura = restricoes.maxWidth;
        final colunas = largura >= 1100
            ? 4
            : largura >= 760
                ? 3
                : 2;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bem-vindo ao NextStock',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SEU ESTOQUE SEMPRE UM PASSO À FRENTE',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: colunas,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    // pula a propria tela inicial
                    children: [
                      for (final m in modulos)
                        if (m.id != 'inicio') _cartao(context, m),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cartao(BuildContext context, ItemNav m) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => aoAbrir?.call(m.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(m.icone, color: corAzul, size: 30),
              const Spacer(),
              Text(
                m.titulo,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
