from models.produto_model import Produto
from models.venda_model import Venda


class DeletarProdutoService:

    def executar(self, id):
        p = Produto.buscar_por_id(id)
        if not p:
            return False
        if Venda.query.filter_by(id_produto=id).first():
            raise ValueError("não dá para apagar: esse produto tem vendas registradas")
        p.deletar()  # os lotes do produto saem junto
        return True
