from datetime import date, timedelta

from repositories.venda_repository import VendaRepository


class MontarRelatorioConsumoService:

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

        agrupado = {}
        total_vendido = 0
        faturamento_total = 0
        for venda in vendas:
            produto = venda.produto
            if not produto:
                continue
            if produto.id_produto not in agrupado:
                agrupado[produto.id_produto] = {
                    "id_produto": produto.id_produto,
                    "produto_nome": produto.nome,
                    "categoria_nome": produto.categoria.nome if produto.categoria else None,
                    "quantidade_vendida": 0,
                    "faturamento": 0,
                }
            valor = venda.quantidade * float(produto.preco_venda or 0)
            agrupado[produto.id_produto]["quantidade_vendida"] += venda.quantidade
            agrupado[produto.id_produto]["faturamento"] += valor
            total_vendido += venda.quantidade
            faturamento_total += valor

        itens = []
        for item in agrupado.values():
            item["faturamento"] = round(item["faturamento"], 2)
            if total_vendido > 0:
                item["percentual_do_total"] = round(
                    item["quantidade_vendida"] / total_vendido * 100, 2
                )
            else:
                item["percentual_do_total"] = 0
            itens.append(item)
        itens.sort(key=lambda i: i["quantidade_vendida"], reverse=True)

        return {
            "dias": dias,
            "total_vendido": total_vendido,
            "faturamento_total": round(faturamento_total, 2),
            "itens": itens,
        }
