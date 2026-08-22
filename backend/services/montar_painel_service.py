from datetime import date, timedelta

from models.produto_model import Produto
from repositories.produto_repository import ProdutoRepository
from repositories.venda_repository import VendaRepository
from services.listar_produtos_em_risco_service import ListarProdutosEmRiscoService


class MontarPainelService:

    def __init__(self):
        self.repo_produto = ProdutoRepository()
        self.repo_venda = VendaRepository()

    def executar(self):
        hoje = date.today()
        produtos = Produto.listar_todos()
        vencidos = self.repo_produto.listar_vencidos()
        vencendo = self.repo_produto.listar_proximos_do_vencimento(7)
        em_risco = ListarProdutosEmRiscoService().executar()
        vendas = self.repo_venda.listar_por_periodo(hoje - timedelta(days=30), hoje)

        itens_em_estoque = 0
        valor_estoque = 0
        for p in produtos:
            qtd = p.quantidade_estoque or 0
            itens_em_estoque += qtd
            valor_estoque += qtd * float(p.preco_custo or 0)

        valor_vencido = 0
        for p in vencidos:
            valor_vencido += (p.quantidade_estoque or 0) * float(p.preco_custo or 0)

        produtos_vencendo = len(vencendo) - len(vencidos)
        if produtos_vencendo < 0:
            produtos_vencendo = 0

        vendas_30_dias = 0
        faturamento_30_dias = 0
        for v in vendas:
            vendas_30_dias += v.quantidade
            if v.produto:
                faturamento_30_dias += v.quantidade * float(v.produto.preco_venda or 0)

        percentual_desperdicio = 0
        if valor_estoque > 0:
            percentual_desperdicio = valor_vencido / valor_estoque * 100

        giro_estoque = 0
        if itens_em_estoque > 0:
            giro_estoque = vendas_30_dias / itens_em_estoque

        return {
            "total_produtos": len(produtos),
            "itens_em_estoque": itens_em_estoque,
            "valor_estoque": round(valor_estoque, 2),
            "produtos_vencidos": len(vencidos),
            "valor_vencido": round(valor_vencido, 2),
            "produtos_vencendo": produtos_vencendo,
            "produtos_em_risco": len(em_risco),
            "vendas_30_dias": vendas_30_dias,
            "faturamento_30_dias": round(faturamento_30_dias, 2),
            "percentual_desperdicio": round(percentual_desperdicio, 2),
            "giro_estoque": round(giro_estoque, 2),
        }
