from models.categoria_model import Categoria


def atualizar_categoria(id, dados):
    c = Categoria.pegarPorId(id)
    if not c:
        return None
    if not dados.get("nome"):
        raise ValueError("nome é obrigatório")

    c.editar(dados["nome"], dados.get("descricao"))
    return c.virarDict()
