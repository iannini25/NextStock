from models.produto_model import Produto


class BuscarProdutoService:

    def executar(self, id):
        p = Produto.buscar_por_id(id)
        if not p:
            return None
        return p.virar_dict()
