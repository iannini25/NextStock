from services.formato_planilha import _texto, _numero, _data
from services.utils import inteiro
from models.database import db
from models.produto_model import Produto
from models.categoria_model import Categoria
from services.estoque_lote_service import EstoqueLoteService


class ImportarProdutoPlanilhaService:

    def executar(self, item):
        nome = _texto(item.get("nome"))
        if not nome:
            raise ValueError("nome é obrigatório")
        preco_venda = _numero(item.get("preco_venda"))
        if preco_venda is None:
            raise ValueError("preco_venda é obrigatório")

        id_categoria = inteiro(_texto(item.get("id_categoria")))
        if id_categoria and not Categoria.buscar_por_id(id_categoria):
            raise ValueError("categoria não existe")

        codigo = _texto(item.get("codigo_barras")) or None
        produto = Produto.buscar_por_codigo(codigo) if codigo else None
        custo = _numero(item.get("preco_custo"))
        # planilha sem a coluna de quantidade: produto que ja existe fica com o estoque que tem
        tem_quantidade = "quantidade_estoque" in item
        qtd = inteiro(_texto(item.get("quantidade_estoque"))) or 0
        minimo = inteiro(_texto(item.get("estoque_minimo"))) or 0
        unidade = (_texto(item.get("unidade")) or "UN").upper()
        validade = _data(item.get("data_validade"))

        estoque = EstoqueLoteService(origem_movimento="planilha")
        novo = produto is None
        if novo:
            produto = Produto(nome=nome, codigo_barras=codigo, quantidade_estoque=0)
        produto.nome = nome
        produto.id_categoria = id_categoria
        produto.codigo_barras = codigo
        produto.preco_custo = custo
        produto.preco_venda = preco_venda
        produto.estoque_minimo = minimo
        produto.unidade = unidade
        try:
            produto.salvar(confirmar=False)
            if novo:  # produto novo: a quantidade da planilha e o saldo inicial dele
                if qtd > 0:
                    estoque.entrada(produto, qtd, data_validade=validade, origem="importacao", tipo="saldo_inicial")
            elif tem_quantidade:  # produto que ja existe: vira ajuste nos lotes (sobrou = lote novo)
                estoque.ajustar_para(produto, qtd, data_validade=validade, origem="importacao")
            produto.salvar()
        except Exception:
            db.session.rollback()
            raise
        return "ok"
