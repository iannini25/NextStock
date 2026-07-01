from models.produto_model import Produto
from models.categoria_model import Categoria
from services.utils import numero, inteiro, virarData


def criar_produto(dados):
    if not dados.get("nome"):
        raise ValueError("nome é obrigatório")
    if not dados.get("preco_venda"):
        raise ValueError("preço de venda é obrigatório")

    # codigo de barras nao pode repetir
    cod = dados.get("codigo_barras") or None
    if cod and Produto.pegarPorCodigo(cod):
        raise ValueError("já existe produto com esse código de barras")

    # se mandou categoria, tem que existir
    cat = dados.get("id_categoria") or None
    if cat and not Categoria.pegarPorId(cat):
        raise ValueError("categoria não existe")

    p = Produto(
        nome=dados["nome"],
        id_categoria=cat,
        codigo_barras=cod,
        preco_custo=numero(dados.get("preco_custo")),
        preco_venda=numero(dados.get("preco_venda")),
        quantidade_estoque=inteiro(dados.get("quantidade_estoque")) or 0,
        unidade=(dados.get("unidade") or "UN").upper(),
        data_validade=virarData(dados.get("data_validade")),
    )
    p.salvar()
    return p.virarDict()
