from datetime import date

from models.produto_model import Produto
from models.venda_model import Venda
from services.utils import inteiro, virar_data


class RegistrarVendaService:

    def executar(self, dados):
        if not dados.get("id_produto"):
            raise ValueError("produto não existe")
        produto = Produto.buscar_por_id(dados.get("id_produto"))
        if not produto:
            raise ValueError("produto não existe")

        quantidade = inteiro(dados.get("quantidade"))
        if not quantidade:
            raise ValueError("quantidade tem que ser maior que zero")

        estoque = produto.quantidade_estoque or 0
        if quantidade > estoque:
            raise ValueError("estoque insuficiente")

        data_venda = virar_data(dados.get("data_venda")) or date.today()

        produto.quantidade_estoque = estoque - quantidade
        produto.salvar()

        venda = Venda(
            id_produto=produto.id_produto,
            quantidade=quantidade,
            data_venda=data_venda,
        )
        venda.salvar()
        return venda.virar_dict()
