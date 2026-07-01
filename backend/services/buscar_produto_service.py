from models.produto_model import Produto


def buscar_produto(id):
    p = Produto.pegarPorId(id)
    if not p:
        return None
    return p.virarDict()
