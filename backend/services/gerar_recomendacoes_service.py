from datetime import date, timedelta

from models.produto_model import Produto
from repositories.venda_repository import VendaRepository
from services.estoque_lote_service import ordenar_lotes_para_saida
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
            vendido = self.repo_venda.total_vendido(produto.id_produto, hoje - timedelta(days=30), hoje)
            media_diaria = vendido / 30
            prev = previsoes.get(produto.id_produto)

            # validade: por lote (cada lote tem a sua). produto antigo sem lote usa a validade do produto
            if produto.lotes:
                lista += self.recomendacoes_de_validade_por_lote(produto)
            else:
                lista += self.recomendacoes_de_validade_do_produto(produto, estoque, hoje)

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

    # lote vencido: retirar. lote que vence em ate 3 dias: vender primeiro / fazer promocao.
    # a mensagem fala da quantidade DAQUELE lote, nao do estoque inteiro do produto
    def recomendacoes_de_validade_por_lote(self, produto):
        recomendacoes = []
        com_saldo = ordenar_lotes_para_saida([l for l in produto.lotes if l.quantidade_atual > 0])
        for lote in com_saldo:
            dias = lote.dias_para_vencer()
            if dias is None:
                continue
            if dias < 0:
                recomendacoes.append(self.montar(
                    produto, "retirar", "alta",
                    f"{lote.titulo()} vencido com {lote.quantidade_atual} em estoque: tire da prateleira",
                    id_lote=lote.id_lote))
            elif dias <= 3:
                mensagem = (f"{lote.titulo()} vence em {dias} dia(s) com {lote.quantidade_atual} em estoque: "
                            "venda primeiro e faça promoção")
                if self.tem_lote_mais_novo(lote, com_saldo):
                    mensagem += " (deixe o lote mais novo pra depois)"
                recomendacoes.append(self.montar(produto, "promocao", "alta", mensagem, id_lote=lote.id_lote))
        return recomendacoes

    @staticmethod
    def tem_lote_mais_novo(lote, lotes):
        for outro in lotes:
            if outro is lote:
                continue
            dias = outro.dias_para_vencer()
            if dias is None or dias > lote.dias_para_vencer():
                return True
        return False

    def recomendacoes_de_validade_do_produto(self, produto, estoque, hoje):
        if not produto.data_validade or estoque <= 0:
            return []
        dias = (produto.data_validade - hoje).days
        if dias < 0:
            return [self.montar(produto, "retirar", "alta", f"Vencido com {estoque} em estoque: tire da prateleira")]
        if dias <= 3:
            return [self.montar(produto, "promocao", "alta",
                                f"Vence em {dias} dia(s) com {estoque} em estoque: faça promoção")]
        return []

    def montar(self, produto, tipo, prioridade, mensagem, id_lote=None):
        return {
            "tipo": tipo,
            "prioridade": prioridade,
            "id_produto": produto.id_produto,
            "produto_nome": produto.nome,
            "id_lote": id_lote,  # so nas recomendacoes de validade por lote
            "mensagem": mensagem,
        }
