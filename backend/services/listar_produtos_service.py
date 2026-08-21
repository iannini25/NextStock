from models.produto_model import Produto


class ListarProdutosService:

    def executar(self):
        return [p.virar_dict() for p in Produto.listar_todos()]
