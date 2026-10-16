from datetime import date

from models.database import db
from models.produto_model import Produto
from models.venda_model import Venda
from services.estoque_lote_service import EstoqueLoteService
from services.utils import inteiro, virar_data


class RegistrarVendaService:

    # baixar_estoque=False so registra a venda no historico (ex.: venda que veio do ERP,
    # que ja manda o estoque atualizado). o padrao continua baixando como sempre.
    # origem = de onde a venda veio (manual, planilha, erp), pro historico de movimentacoes
    def executar(self, dados, baixar_estoque=True, origem="manual"):
        if not dados.get("id_produto"):
            raise ValueError("produto não existe")
        produto = Produto.buscar_por_id(dados.get("id_produto"))
        if not produto:
            raise ValueError("produto não existe")

        quantidade = inteiro(dados.get("quantidade"))
        if not quantidade:
            raise ValueError("quantidade tem que ser maior que zero")

        data_venda = virar_data(dados.get("data_venda")) or date.today()

        # venda + baixa nos lotes + historico gravados juntos: ou entra tudo, ou nada
        try:
            venda = Venda(
                id_produto=produto.id_produto,
                quantidade=quantidade,
                data_venda=data_venda,
            )
            db.session.add(venda)
            db.session.flush()  # gera o id da venda pro historico, sem gravar ainda
            if baixar_estoque:
                # "estoque insuficiente" sai daqui (e a venda acima nao chega a ser gravada)
                EstoqueLoteService(origem_movimento=origem).baixar(produto, quantidade, id_venda=venda.id_venda)
            db.session.commit()
        except Exception:
            db.session.rollback()
            raise
        return venda.virar_dict()
