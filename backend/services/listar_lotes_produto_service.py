from datetime import date

from models.database import db
from models.produto_model import Produto
from services.estoque_lote_service import EstoqueLoteService
from services.priorizar_lotes_service import PriorizarLotesService


class ListarLotesProdutoService:

    def __init__(self, produto_model=None, estoque=None, prioridade=None, hoje=None):
        self.produto_model = produto_model if produto_model is not None else Produto
        self.estoque = estoque if estoque is not None else EstoqueLoteService(origem_movimento="sistema")
        self.prioridade = prioridade if prioridade is not None else PriorizarLotesService()
        self.hoje = hoje if hoje is not None else date.today

    # lotes com saldo na ordem de saida; com todos=True, os esgotados vem depois (mais recentes primeiro)
    def executar(self, id_produto, todos=False):
        produto = self.produto_model.buscar_por_id(id_produto)
        if not produto:
            return None
        if (produto.quantidade_estoque or 0) > 0 and not produto.lotes:  # dado antigo: cria o estoque inicial
            self.estoque.garantir_lote_inicial(produto)
            db.session.commit()

        # os com saldo vem na ordem de saida, com posicao_saida e vender_primeiro (Etapa 9)
        hoje = self.hoje()
        lotes = self.montar_ordem(produto, hoje)
        if todos:
            esgotados = [l for l in produto.lotes if l.quantidade_atual <= 0]
            esgotados = sorted(esgotados, key=lambda l: (l.data_entrada, l.id_lote), reverse=True)
            lotes += [{**l.virar_dict(hoje), "posicao_saida": None, "vender_primeiro": False} for l in esgotados]
        return {"produto": produto.virar_dict(), "lotes": lotes}

    def montar_ordem(self, produto, hoje=None):
        hoje = hoje if hoje is not None else self.hoje()
        ordenados = self.prioridade.executar(
            [lote for lote in produto.lotes if lote.quantidade_atual > 0], hoje=hoje)
        primeiro_bom = next((lote for lote in ordenados
                             if lote.data_validade is None or lote.data_validade >= hoje), None)
        return [{**lote.virar_dict(hoje), "posicao_saida": posicao,
                 "vender_primeiro": lote is primeiro_bom}
                for posicao, lote in enumerate(ordenados, start=1)]
