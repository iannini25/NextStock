from datetime import date, timedelta

from models.produto_model import Produto
from repositories.venda_repository import VendaRepository
from services.prever_demanda_service import PreverDemandaService


class GerarRecomendacoesService:

    def __init__(self):
        self.repo_venda = VendaRepository()

    def executar(self):
        hoje = date.today()
        previsoes = {p["id_produto"]: p for p in PreverDemandaService().executar(7, "auto")}
        lista = []
        for produto in Produto.listar_todos():
            estoque = produto.quantidade_estoque or 0
            minimo = produto.estoque_minimo or 0
            dias_para_vencer = None
            if produto.data_validade:
                dias_para_vencer = (produto.data_validade - hoje).days
            vendido = self.repo_venda.total_vendido(produto.id_produto, hoje - timedelta(days=30), hoje)
            media_diaria = vendido / 30
            prev = previsoes.get(produto.id_produto)

            if dias_para_vencer is not None and dias_para_vencer < 0 and estoque > 0:
                lista.append(self.montar(produto, "retirar", "alta",
                                         f"Vencido com {estoque} em estoque: tire da prateleira"))
            if dias_para_vencer is not None and 0 <= dias_para_vencer <= 3 and estoque > 0:
                lista.append(self.montar(produto, "promocao", "alta",
                                         f"Vence em {dias_para_vencer} dia(s) com {estoque} em estoque: faça promoção"))
            if minimo > 0 and estoque <= minimo:
                lista.append(self.montar(produto, "repor", "alta",
                                         f"Estoque ({estoque}) no mínimo ({minimo}): repor agora"))
            elif prev and prev["previsao_demanda"] > estoque:
                lista.append(self.montar(produto, "repor", "alta",
                                         f"Clima dos próximos 7 dias: demanda prevista {prev['previsao_demanda']} acima do estoque {estoque}"))
            if media_diaria > 0 and estoque / media_diaria > 30:
                lista.append(self.montar(produto, "comprar_menos", "media",
                                         f"Estoque cobre {int(estoque / media_diaria)} dias de venda: compre menos"))
            if vendido == 0 and estoque > 0:
                lista.append(self.montar(produto, "produto_parado", "media",
                                         "Sem venda em 30 dias: avalie promoção ou tirar do mix"))

        ordem = {"alta": 0, "media": 1, "baixa": 2}
        lista.sort(key=lambda r: ordem[r["prioridade"]])
        return lista

    def montar(self, produto, tipo, prioridade, mensagem):
        return {
            "tipo": tipo,
            "prioridade": prioridade,
            "id_produto": produto.id_produto,
            "produto_nome": produto.nome,
            "mensagem": mensagem,
        }
