from datetime import date, timedelta

from models.produto_model import Produto
from repositories.venda_repository import VendaRepository


class MontarRelatorioTendenciasService:

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
        atual_inicio = hoje - timedelta(days=dias)
        anterior_inicio = hoje - timedelta(days=dias * 2)
        anterior_fim = atual_inicio - timedelta(days=1)

        atual = self.somar(self.repo.listar_por_periodo(atual_inicio, hoje))
        anterior = self.somar(self.repo.listar_por_periodo(anterior_inicio, anterior_fim))

        lista = []
        for produto in Produto.listar_todos():
            qtd_atual = atual.get(produto.id_produto, 0)
            qtd_anterior = anterior.get(produto.id_produto, 0)
            if qtd_atual == 0 and qtd_anterior == 0:
                continue
            if qtd_anterior == 0:
                variacao = 100
            else:
                variacao = (qtd_atual - qtd_anterior) / qtd_anterior * 100
            if variacao > 10:
                tendencia = "subindo"
            elif variacao < -10:
                tendencia = "caindo"
            else:
                tendencia = "estavel"
            lista.append({
                "id_produto": produto.id_produto,
                "produto_nome": produto.nome,
                "vendas_periodo_anterior": qtd_anterior,
                "vendas_periodo_atual": qtd_atual,
                "variacao_percentual": round(variacao, 2),
                "tendencia": tendencia,
            })
        lista.sort(key=lambda t: t["variacao_percentual"], reverse=True)
        return lista

    def somar(self, vendas):
        totais = {}
        for venda in vendas:
            totais[venda.id_produto] = totais.get(venda.id_produto, 0) + venda.quantidade
        return totais
