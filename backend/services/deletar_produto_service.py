from models.produto_model import Produto


class DeletarProdutoService:

    def executar(self, id):
        p = Produto.buscar_por_id(id)
        if not p:
            return False
        p.deletar()
        return True
