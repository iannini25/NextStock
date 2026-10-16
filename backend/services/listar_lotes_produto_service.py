from models.database import db
from models.produto_model import Produto
from services.estoque_lote_service import EstoqueLoteService, ordenar_lotes_para_saida


class ListarLotesProdutoService:

    # lotes com saldo na ordem de saida; com todos=True, os esgotados vem depois (mais recentes primeiro)
    def executar(self, id_produto, todos=False):
        produto = Produto.buscar_por_id(id_produto)
        if not produto:
            return None
        if (produto.quantidade_estoque or 0) > 0 and not produto.lotes:  # dado antigo: cria o estoque inicial
            EstoqueLoteService().garantir_lote_inicial(produto)
            db.session.commit()

        com_saldo = ordenar_lotes_para_saida([l for l in produto.lotes if l.quantidade_atual > 0])
        lotes = list(com_saldo)
        if todos:
            esgotados = [l for l in produto.lotes if l.quantidade_atual <= 0]
            lotes += sorted(esgotados, key=lambda l: (l.data_entrada, l.id_lote), reverse=True)
        return {"produto": produto.virar_dict(), "lotes": [l.virar_dict() for l in lotes]}
