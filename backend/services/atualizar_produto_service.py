from models.produto_model import Produto
from models.categoria_model import Categoria
from services.utils import numero, inteiro, virarData


def atualizar_produto(id, dados):
    p = Produto.pegarPorId(id)
    if not p:
        return None

    if not dados.get("nome"):
        raise ValueError("nome é obrigatório")
    if not dados.get("preco_venda"):
        raise ValueError("preço de venda é obrigatório")

    # codigo de barras: so da problema se for de OUTRO produto
    cod = dados.get("codigo_barras") or None
    if cod:
        outro = Produto.pegarPorCodigo(cod)
        if outro and outro.id_produto != id:
            raise ValueError("já existe produto com esse código de barras")

    cat = dados.get("id_categoria") or None
    if cat and not Categoria.pegarPorId(cat):
        raise ValueError("categoria não existe")

    p.editar(
        dados["nome"],
        cat,
        cod,
        numero(dados.get("preco_custo")),
        numero(dados.get("preco_venda")),
        inteiro(dados.get("quantidade_estoque")) or 0,
        (dados.get("unidade") or "UN").upper(),
        virarData(dados.get("data_validade")),
    )
    return p.virarDict()
