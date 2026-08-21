from models.produto_model import Produto
from models.categoria_model import Categoria
from services.utils import numero, inteiro, virar_data


class CriarProdutoService:

    def executar(self, dados):
        if not dados.get("nome"):
            raise ValueError("nome é obrigatório")
        if not dados.get("preco_venda"):
            raise ValueError("preço de venda é obrigatório")

        # codigo de barras nao pode repetir
        cod = dados.get("codigo_barras") or None
        if cod and Produto.buscar_por_codigo(cod):
            raise ValueError("já existe produto com esse código de barras")

        # se mandou categoria, tem que existir
        cat = dados.get("id_categoria") or None
        if cat and not Categoria.buscar_por_id(cat):
            raise ValueError("categoria não existe")

        p = Produto(
            nome=dados["nome"],
            id_categoria=cat,
            codigo_barras=cod,
            preco_custo=numero(dados.get("preco_custo")),
            preco_venda=numero(dados.get("preco_venda")),
            quantidade_estoque=inteiro(dados.get("quantidade_estoque")) or 0,
            estoque_minimo=inteiro(dados.get("estoque_minimo")) or 0,
            unidade=(dados.get("unidade") or "UN").upper(),
            data_validade=virar_data(dados.get("data_validade")),
        )
        p.salvar()
        return p.virar_dict()
