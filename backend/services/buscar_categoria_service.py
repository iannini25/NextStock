from models.categoria_model import Categoria


def buscar_categoria(id):
    c = Categoria.pegarPorId(id)
    if not c:
        return None
    return c.virarDict()
