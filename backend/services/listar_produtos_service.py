from models.produto_model import Produto


def listar_produtos():
    return [p.virarDict() for p in Produto.pegarTodos()]
