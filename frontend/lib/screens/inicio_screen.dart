import 'package:flutter/material.dart';
import '../main.dart';
import '../services/sessao.dart';
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
                children: [
                  const SizedBox(height: 8),
                  Text(
                    saudacao(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'SEU ESTOQUE SEMPRE UM PASSO À FRENTE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    // altura fixa dos cartoes, assim nao estoura em tela pequena
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: colunas,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 150,
                    ),
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

  // "Ola, Fulano" com o primeiro nome de quem esta logado
  String saudacao() {
    final nome = Sessao.usuario.value?.nome.trim() ?? '';
    if (nome.isEmpty) return 'Bem-vindo ao NextStock';
    return 'Olá, ${nome.split(' ').first}';
  }

  Widget _cartao(BuildContext context, ItemNav m) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => aoAbrir?.call(m.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // icone grande dentro de um circulo azul claro
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: corAzul.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(m.icone, color: corAzul, size: 36),
              ),
              const SizedBox(height: 12),
              Text(
                m.titulo,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
