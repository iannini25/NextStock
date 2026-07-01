from models.categoria_model import Categoria


def deletar_categoria(id):
    c = Categoria.pegarPorId(id)
    if not c:
        return False
    c.apagar()
    return True
