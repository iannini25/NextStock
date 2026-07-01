from models.categoria_model import Categoria


def listar_categorias():
    return [c.virarDict() for c in Categoria.pegarTodas()]
