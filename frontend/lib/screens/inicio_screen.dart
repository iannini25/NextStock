import 'package:flutter/material.dart';
import '../main.dart';
import 'categorias_screen.dart';
import 'vendas_screen.dart';
import 'eventos_screen.dart';
import 'previsao_screen.dart';
import 'compras_screen.dart';
import 'reposicao_screen.dart';
import 'painel_screen.dart';
import 'recomendacoes_screen.dart';
import 'relatorios_screen.dart';
import 'importar_erp_screen.dart';

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NextStock')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Image.asset('assets/logo.png', height: 100),
                const SizedBox(height: 12),
                Image.asset('assets/nome.png', height: 36),
                const SizedBox(height: 8),
                const Text(
                  'SEU ESTOQUE SEMPRE UM PASSO À FRENTE',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, letterSpacing: 2, color: corNavy),
                ),
              ],
            ),
          ),
          const Divider(),
          montarItem(context, Icons.category, 'Categorias', const CategoriasScreen()),
          montarItem(context, Icons.point_of_sale, 'Vendas', const VendasScreen()),
          montarItem(context, Icons.event, 'Eventos locais', const EventosScreen()),
          montarItem(context, Icons.trending_up, 'Previsão de demanda', const PrevisaoScreen()),
          montarItem(context, Icons.shopping_cart, 'Sugestão de compras', const ComprasScreen()),
          montarItem(context, Icons.autorenew, 'Reposição', const ReposicaoScreen()),
          montarItem(context, Icons.dashboard, 'Painel gerencial', const PainelScreen()),
          montarItem(context, Icons.lightbulb, 'Recomendações', const RecomendacoesScreen()),
          montarItem(context, Icons.bar_chart, 'Relatórios', const RelatoriosScreen()),
          montarItem(context, Icons.cloud_upload, 'Importar do ERP', const ImportarErpScreen()),
        ],
      ),
    );
  }

  Widget montarItem(BuildContext context, IconData icone, String titulo, Widget tela) {
    return ListTile(
      leading: Icon(icone, color: corAzul),
      title: Text(titulo),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => tela)),
    );
  }
}
