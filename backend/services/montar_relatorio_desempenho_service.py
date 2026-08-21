from datetime import date, timedelta

from models.produto_model import Produto
from repositories.venda_repository import VendaRepository


class MontarRelatorioDesempenhoService:

    def __init__(self):
        self.repo = VendaRepository()

    def executar(self, dias):
        try:
            dias = int(dias)
        except (TypeError, ValueError):
            dias = 30
        if dias < 1 or dias > 365:
            raise ValueError("dias tem que ser entre 1 e 365")

        hoje = date.today()
        vendas = self.repo.listar_por_periodo(hoje - timedelta(days=dias), hoje)

        por_produto = {}
        for produto in Produto.listar_todos():
            por_produto[produto.id_produto] = {
                "id_produto": produto.id_produto,
                "produto_nome": produto.nome,
                "quantidade_vendida": 0,
                "faturamento": 0,
            }

        for venda in vendas:
            if venda.id_produto not in por_produto:
                continue
            produto = venda.produto
            por_produto[venda.id_produto]["quantidade_vendida"] += venda.quantidade
            if produto:
                por_produto[venda.id_produto]["faturamento"] += (
                    venda.quantidade * float(produto.preco_venda or 0)
                )

        ranking = list(por_produto.values())
        ranking.sort(key=lambda i: i["quantidade_vendida"], reverse=True)
        for item in ranking:
            item["faturamento"] = round(item["faturamento"], 2)

        mais = ranking[:5]
        menos = list(reversed(ranking[-5:])) if ranking else []

        margens = []
        for produto in Produto.listar_todos():
            custo = float(produto.preco_custo) if produto.preco_custo is not None else None
            venda = float(produto.preco_venda) if produto.preco_venda is not None else None
            margem = 0
            if custo is not None and venda and venda > 0:
                margem = (venda - custo) / venda * 100
            margens.append({
                "id_produto": produto.id_produto,
                "produto_nome": produto.nome,
                "preco_custo": custo,
                "preco_venda": venda,
                "margem_percentual": round(margem, 2),
            })
        margens.sort(key=lambda m: m["margem_percentual"], reverse=True)

        return {
            "mais_vendidos": mais,
            "menos_vendidos": menos,
            "margens": margens,
        }
