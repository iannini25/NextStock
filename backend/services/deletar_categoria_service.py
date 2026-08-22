from models.categoria_model import Categoria
from models.produto_model import Produto


class DeletarCategoriaService:

    def executar(self, id):
        c = Categoria.buscar_por_id(id)
        if not c:
            return False
        if Produto.query.filter_by(id_categoria=id).first():
            raise ValueError("não dá para apagar: existem produtos nessa categoria")
        c.deletar()
        return True
