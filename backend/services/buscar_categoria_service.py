from models.categoria_model import Categoria


class BuscarCategoriaService:

    def executar(self, id):
        c = Categoria.buscar_por_id(id)
        if not c:
            return None
        return c.virar_dict()
