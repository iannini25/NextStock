from models.categoria_model import Categoria


class DeletarCategoriaService:

    def executar(self, id):
        c = Categoria.buscar_por_id(id)
        if not c:
            return False
        c.deletar()
        return True
