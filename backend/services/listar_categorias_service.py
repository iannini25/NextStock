from models.categoria_model import Categoria


class ListarCategoriasService:

    def executar(self):
        return [c.virar_dict() for c in Categoria.listar_todos()]
