from models.database import db
from models.lote_model import Lote
from services.estoque_lote_service import EstoqueLoteService
from services.utils import virar_data, virar_texto


# corrige o codigo ou a validade digitados errado. a quantidade nao muda por aqui
# (entra por entrada de mercadoria e sai por venda).
class CorrigirLoteService:

    def __init__(self, lote_model=None, estoque=None):
        self.lote_model = lote_model if lote_model is not None else Lote
        self.estoque = estoque if estoque is not None else EstoqueLoteService()

    def executar(self, id_lote, dados):
        if not isinstance(dados, dict):
            raise ValueError("os dados precisam ser um objeto JSON")
        lote = self.lote_model.buscar_por_id(id_lote)
        if not lote:
            return None
        codigo = virar_texto(dados.get("codigo_lote"), "código do lote", 50)
        validade = virar_data(dados.get("data_validade"))
        try:
            lote.atualizar(codigo, validade, confirmar=False)
            self.estoque.sincronizar_produto(lote.produto)
            lote.salvar()
        except Exception:
            db.session.rollback()
            raise
        return {"lote": lote.virar_dict(), "produto": lote.produto.virar_dict()}
