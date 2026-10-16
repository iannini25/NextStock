from models.database import db
from models.lote_model import Lote
from services.estoque_lote_service import EstoqueLoteService
from services.utils import virar_data, virar_texto


# corrige o codigo ou a validade digitados errado. a quantidade nao muda por aqui
# (entra por entrada de mercadoria e sai por venda).
class CorrigirLoteService:

    def executar(self, id_lote, dados):
        lote = Lote.buscar_por_id(id_lote)
        if not lote:
            return None
        codigo = virar_texto(dados.get("codigo_lote"), "código do lote", 50)
        validade = virar_data(dados.get("data_validade"))
        lote.codigo_lote = codigo
        lote.data_validade = validade
        EstoqueLoteService().sincronizar_produto(lote.produto)  # a validade do produto pode mudar
        db.session.commit()
        return {"lote": lote.virar_dict(), "produto": lote.produto.virar_dict()}
