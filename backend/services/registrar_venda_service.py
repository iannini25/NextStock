from datetime import date

from models.database import db
from models.produto_model import Produto
from models.venda_model import Venda
from services.estoque_lote_service import EstoqueLoteService
from services.planejar_saida_service import PlanejarSaidaService
from services.utils import virar_data


class RegistrarVendaService:

    def __init__(self, produto_model=None, venda_model=None, estoque=None, hoje=None):
        self.produto_model = produto_model if produto_model is not None else Produto
        self.venda_model = venda_model if venda_model is not None else Venda
        self.estoque = estoque
        self.hoje = hoje if hoje is not None else date.today

    # baixar_estoque=False so registra a venda no historico (ex.: venda que veio do ERP,
    # que ja manda o estoque atualizado). o padrao continua baixando como sempre.
    # origem = de onde a venda veio (manual, planilha, erp), pro historico de movimentacoes
    def executar(self, dados, baixar_estoque=True, origem="manual", confirmar=True):
        if not isinstance(dados, dict):
            raise ValueError("os dados precisam ser um objeto JSON")
        if not dados.get("id_produto"):
            raise ValueError("produto não existe")
        produto = self.produto_model.buscar_por_id(dados.get("id_produto"))
        if not produto:
            raise ValueError("produto não existe")

        quantidade = PlanejarSaidaService.validar_quantidade(dados.get("quantidade"))

        hoje = self.hoje()
        data_venda = virar_data(dados.get("data_venda")) or hoje

        # venda + baixa nos lotes + historico gravados juntos: ou entra tudo, ou nada
        try:
            venda = self.venda_model(
                id_produto=produto.id_produto,
                quantidade=quantidade,
                data_venda=data_venda,
            )
            venda.salvar(confirmar=False)
            consumidos = []
            if baixar_estoque:
                # "estoque insuficiente" sai daqui (e a venda acima nao chega a ser gravada)
                estoque = self.estoque if self.estoque is not None else EstoqueLoteService(origem_movimento=origem)
                consumidos = estoque.baixar(
                    produto, quantidade, id_venda=venda.id_venda)
            venda.salvar() if confirmar else venda.salvar(confirmar=False)
        except Exception:
            db.session.rollback()
            raise
        resposta = venda.virar_dict()
        # de quais lotes a venda saiu (vazio quando nao baixa estoque)
        resposta["lotes_consumidos"] = [lote.saida(sai, hoje) for lote, sai in consumidos]
        return resposta
