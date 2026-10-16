from datetime import date

from models.produto_model import Produto
from models.venda_model import Venda
from services.utils import inteiro, virar_data


class RegistrarVendaService:

    # baixar_estoque=False so registra a venda no historico (ex.: venda que veio do ERP,
    # que ja manda o estoque atualizado). o padrao continua baixando como sempre.
    def executar(self, dados, baixar_estoque=True):
        if not dados.get("id_produto"):
            raise ValueError("produto não existe")
        produto = Produto.buscar_por_id(dados.get("id_produto"))
        if not produto:
            raise ValueError("produto não existe")

        quantidade = inteiro(dados.get("quantidade"))
        if not quantidade:
            raise ValueError("quantidade tem que ser maior que zero")

        estoque = produto.quantidade_estoque or 0
        if baixar_estoque and quantidade > estoque:
            raise ValueError("estoque insuficiente")

        data_venda = virar_data(dados.get("data_venda")) or date.today()

        if baixar_estoque:
            produto.quantidade_estoque = estoque - quantidade
            produto.salvar()

        venda = Venda(
            id_produto=produto.id_produto,
            quantidade=quantidade,
            data_venda=data_venda,
        )
        venda.salvar()
        return venda.virar_dict()
