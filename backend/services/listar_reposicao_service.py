import math
from datetime import date, timedelta

from models.produto_model import Produto
from repositories.venda_repository import VendaRepository
from services.prever_demanda_service import PreverDemandaService


class ListarReposicaoService:

    def __init__(self):
        self.repo_venda = VendaRepository()

    def executar(self):
        hoje = date.today()
        lista = []
        for produto in Produto.listar_todos():
            item = self.montar(produto, hoje)
            if item:
                lista.append(item)
        previsoes = {p["id_produto"]: p for p in PreverDemandaService().executar(7, "auto")}
        ids = {r["id_produto"] for r in lista}
        for pid, prev in previsoes.items():
            if prev["previsao_demanda"] <= prev["estoque_atual"]:
                continue
            if pid in ids:
                for r in lista:
                    if r["id_produto"] == pid:
                        r["urgencia"] = "alta"
                        r["prazo_ideal"] = "hoje"
                        r["dias_ate_minimo"] = 0
                continue
            produto = Produto.buscar_por_id(pid)
            if not produto:
                continue
            minimo = produto.estoque_minimo or 0
            lista.append({
                "id_produto": produto.id_produto,
                "produto_nome": produto.nome,
                "unidade": produto.unidade,
                "estoque_atual": prev["estoque_atual"],
                "estoque_minimo": minimo,
                "media_diaria": prev["media_diaria"],
                "dias_ate_minimo": 0,
                "prazo_ideal": "hoje",
                "quantidade_ideal": prev["previsao_demanda"] - prev["estoque_atual"],
                "urgencia": "alta",
            })
            ids.add(pid)

        ordem = {"alta": 0, "media": 1, "baixa": 2}
        lista.sort(key=lambda r: (ordem[r["urgencia"]], r["dias_ate_minimo"]))
        return lista

    def montar(self, produto, hoje):
        estoque = produto.quantidade_estoque or 0
        minimo = produto.estoque_minimo or 0
        vendido = self.repo_venda.total_vendido(
            produto.id_produto, hoje - timedelta(days=30), hoje
        )
        media_diaria = vendido / 30

        if media_diaria <= 0:
            if minimo > 0 and estoque <= minimo:
                return {
                    "id_produto": produto.id_produto,
                    "produto_nome": produto.nome,
                    "unidade": produto.unidade,
                    "estoque_atual": estoque,
                    "estoque_minimo": minimo,
                    "media_diaria": 0,
                    "dias_ate_minimo": 0,
                    "prazo_ideal": "hoje",
                    "quantidade_ideal": max(minimo - estoque, minimo),
                    "urgencia": "alta",
                }
            return None

        folga = estoque - minimo
        if folga <= 0:
            dias_ate_minimo = 0
        else:
            dias_ate_minimo = int(folga / media_diaria)

        if dias_ate_minimo > 14:
            return None

        if dias_ate_minimo == 0:
            prazo_ideal = "hoje"
            urgencia = "alta"
        elif dias_ate_minimo <= 3:
            prazo_ideal = "em " + str(dias_ate_minimo) + " dia(s)"
            urgencia = "alta"
        elif dias_ate_minimo <= 7:
            prazo_ideal = "em " + str(dias_ate_minimo) + " dia(s)"
            urgencia = "media"
        else:
            prazo_ideal = "em " + str(dias_ate_minimo) + " dia(s)"
            urgencia = "baixa"

        quantidade_ideal = math.ceil(media_diaria * 7)
        if estoque < minimo:
            quantidade_ideal += minimo - estoque

        return {
            "id_produto": produto.id_produto,
            "produto_nome": produto.nome,
            "unidade": produto.unidade,
            "estoque_atual": estoque,
            "estoque_minimo": minimo,
            "media_diaria": round(media_diaria, 2),
            "dias_ate_minimo": dias_ate_minimo,
            "prazo_ideal": prazo_ideal,
            "quantidade_ideal": quantidade_ideal,
            "urgencia": urgencia,
        }
