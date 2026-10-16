from models.database import db
from models.produto_model import Produto
from models.categoria_model import Categoria
from services.estoque_lote_service import EstoqueLoteService
from services.situacao_local import virar_local
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

        quantidade = inteiro(dados.get("quantidade_estoque")) or 0
        validade = virar_data(dados.get("data_validade"))
        id_local = virar_local(dados.get("id_local_armazenamento"))  # opcional

        p = Produto(
            nome=dados["nome"],
            id_categoria=cat,
            codigo_barras=cod,
            preco_custo=numero(dados.get("preco_custo")),
            preco_venda=numero(dados.get("preco_venda")),
            quantidade_estoque=0,
            estoque_minimo=inteiro(dados.get("estoque_minimo")) or 0,
            unidade=(dados.get("unidade") or "UN").upper(),
            id_local_armazenamento=id_local,
        )
        db.session.add(p)
        # a quantidade e a validade do cadastro viram o primeiro lote do produto
        if quantidade > 0:
            EstoqueLoteService().entrada(p, quantidade, data_validade=validade, origem="inicial")
        db.session.commit()
        return p.virar_dict()
