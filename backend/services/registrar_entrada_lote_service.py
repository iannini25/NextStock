from datetime import date

from models.database import db
from models.produto_model import Produto
from services.estoque_lote_service import EstoqueLoteService
from services.utils import inteiro, numero, virar_data, virar_texto


# entrada de mercadoria: cria um lote e o estoque do produto aumenta
class RegistrarEntradaLoteService:

    def executar(self, dados):
        produto = Produto.buscar_por_id(dados.get("id_produto")) if dados.get("id_produto") else None
        if not produto:
            raise ValueError("produto não existe")
        quantidade = inteiro(dados.get("quantidade"))
        if not quantidade:
            raise ValueError("quantidade tem que ser maior que zero")
        validade = virar_data(dados.get("data_validade"))
        entrada = virar_data(dados.get("data_entrada")) or date.today()
        if entrada > date.today():
            raise ValueError("data de entrada não pode ser no futuro")
        custo = numero(dados.get("custo_unitario"))
        codigo = virar_texto(dados.get("codigo_lote"), "código do lote", 50)

        try:
            lote = EstoqueLoteService().entrada(produto, quantidade, data_validade=validade, codigo_lote=codigo,
                                                custo_unitario=custo, data_entrada=entrada)
            db.session.commit()
        except Exception:
            db.session.rollback()
            raise
        return {"lote": lote.virar_dict(), "produto": produto.virar_dict()}
