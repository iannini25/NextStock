from models.produto_model import Produto


def deletar_produto(id):
    p = Produto.pegarPorId(id)
    if not p:
        return False
    p.apagar()
    return True
