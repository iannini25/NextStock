from models.database import db
from models.produto_model import Produto
from services.estoque_lote_service import EstoqueLoteService
from services.ordem_saida_service import lotes_na_ordem_de_saida


class ListarLotesProdutoService:

    # lotes com saldo na ordem de saida; com todos=True, os esgotados vem depois (mais recentes primeiro)
    def executar(self, id_produto, todos=False):
        produto = Produto.buscar_por_id(id_produto)
        if not produto:
            return None
        if (produto.quantidade_estoque or 0) > 0 and not produto.lotes:  # dado antigo: cria o estoque inicial
            EstoqueLoteService(origem_movimento="sistema").garantir_lote_inicial(produto)
            db.session.commit()

        # os com saldo vem na ordem de saida, com posicao_saida e vender_primeiro (Etapa 9)
        lotes = lotes_na_ordem_de_saida(produto)
        if todos:
            esgotados = [l for l in produto.lotes if l.quantidade_atual <= 0]
            esgotados = sorted(esgotados, key=lambda l: (l.data_entrada, l.id_lote), reverse=True)
            lotes += [{**l.virar_dict(), "posicao_saida": None, "vender_primeiro": False} for l in esgotados]
        return {"produto": produto.virar_dict(), "lotes": lotes}
