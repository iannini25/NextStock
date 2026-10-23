from datetime import date
from math import isfinite

from models.database import db
from models.produto_model import Produto
from services.estoque_lote_service import EstoqueLoteService
from services.planejar_saida_service import PlanejarSaidaService
from services.utils import numero, virar_data, virar_texto


# entrada de mercadoria: cria um lote e o estoque do produto aumenta
class RegistrarEntradaLoteService:

    def __init__(self, produto_model=None, estoque=None, hoje=None):
        self.produto_model = produto_model if produto_model is not None else Produto
        self.estoque = estoque if estoque is not None else EstoqueLoteService()
        self.hoje = hoje if hoje is not None else date.today

    def executar(self, dados):
        if not isinstance(dados, dict):
            raise ValueError("os dados precisam ser um objeto JSON")
        produto = self.produto_model.buscar_por_id(dados.get("id_produto")) if dados.get("id_produto") else None
        if not produto:
            raise ValueError("produto não existe")
        quantidade = PlanejarSaidaService.validar_quantidade(dados.get("quantidade"))
        validade = virar_data(dados.get("data_validade"))
        hoje = self.hoje()
        entrada = virar_data(dados.get("data_entrada")) or hoje
        if entrada > hoje:
            raise ValueError("data de entrada não pode ser no futuro")
        custo = numero(dados.get("custo_unitario"))
        if custo is not None and not isfinite(custo):
            raise ValueError("custo precisa ser um número finito")
        codigo = virar_texto(dados.get("codigo_lote"), "código do lote", 50)

        try:
            lote = self.estoque.entrada(produto, quantidade, data_validade=validade, codigo_lote=codigo,
                                                custo_unitario=custo, data_entrada=entrada)
            lote.salvar()
        except Exception:
            db.session.rollback()
            raise
        return {"lote": lote.virar_dict(), "produto": produto.virar_dict()}
