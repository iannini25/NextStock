from models.categoria_model import Categoria


def criar_categoria(dados):
    if not dados.get("nome"):
        raise ValueError("nome é obrigatório")

    c = Categoria(nome=dados["nome"], descricao=dados.get("descricao"))
    c.salvar()
    return c.virarDict()
