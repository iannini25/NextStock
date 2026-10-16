from models.database import db
from models.produto_model import Produto
from models.categoria_model import Categoria
from services.estoque_lote_service import EstoqueLoteService
from services.situacao_local import virar_local
from services.utils import numero, inteiro, virar_data


class AtualizarProdutoService:

    def executar(self, id, dados):
        p = Produto.buscar_por_id(id)
        if not p:
            return None

        if not dados.get("nome"):
            raise ValueError("nome é obrigatório")
        if not dados.get("preco_venda"):
            raise ValueError("preço de venda é obrigatório")

        # codigo de barras: so da problema se for de OUTRO produto
        cod = dados.get("codigo_barras") or None
        if cod:
            outro = Produto.buscar_por_codigo(cod)
            if outro and outro.id_produto != id:
                raise ValueError("já existe produto com esse código de barras")

        cat = dados.get("id_categoria") or None
        if cat and not Categoria.buscar_por_id(cat):
            raise ValueError("categoria não existe")

        # quantidade e validade agora sao dos lotes:
        #   - sem quantidade_estoque (ou null): o estoque fica como esta (a tela de edicao nao manda mais)
        #   - com quantidade_estoque: vira um ajuste nos lotes (sobrou = lote novo com essa validade; faltou = baixa)
        nova_quantidade = None
        if dados.get("quantidade_estoque") is not None:
            nova_quantidade = inteiro(dados.get("quantidade_estoque")) or 0
        validade = virar_data(dados.get("data_validade"))
        # valida tudo antes de mexer no produto
        custo = numero(dados.get("preco_custo"))
        venda = numero(dados.get("preco_venda"))
        minimo = inteiro(dados.get("estoque_minimo")) or 0
        unidade = (dados.get("unidade") or "UN").upper()
        # local de armazenamento: sem o campo, fica como esta (quem nao conhece o campo nao apaga o local);
        # com o campo vazio/null, o produto fica sem local
        mexer_no_local = "id_local_armazenamento" in dados
        if mexer_no_local:
            id_local = virar_local(dados.get("id_local_armazenamento"), atual=p.id_local_armazenamento)

        p.nome = dados["nome"]
        p.id_categoria = cat
        p.codigo_barras = cod
        p.preco_custo = custo
        p.preco_venda = venda
        p.estoque_minimo = minimo
        p.unidade = unidade
        if mexer_no_local:
            p.id_local_armazenamento = id_local
        try:
            if nova_quantidade is not None:
                EstoqueLoteService().ajustar_para(p, nova_quantidade, data_validade=validade)
            db.session.commit()
        except Exception:
            db.session.rollback()
            raise
        return p.virar_dict()
