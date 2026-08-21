from datetime import date

from models.produto_model import Produto
from models.categoria_model import Categoria
from models.venda_model import Venda
from services.utils import numero, inteiro, virar_data


class ImportarErpService:

    def executar(self, dados):
        produtos = dados.get("produtos") or []
        vendas = dados.get("vendas") or []
        if not produtos and not vendas:
            raise ValueError("manda pelo menos produtos ou vendas")

        criados = 0
        atualizados = 0
        importadas = 0
        erros = []

        for item in produtos:
            try:
                resultado = self.importar_produto(item)
                if resultado == "criado":
                    criados += 1
                else:
                    atualizados += 1
            except ValueError as e:
                erros.append("produto " + str(item.get("codigo_barras")) + ": " + str(e))

        for item in vendas:
            try:
                self.importar_venda(item)
                importadas += 1
            except ValueError as e:
                erros.append("venda " + str(item.get("codigo_barras")) + ": " + str(e))

        return {
            "produtos_criados": criados,
            "produtos_atualizados": atualizados,
            "vendas_importadas": importadas,
            "erros": erros,
        }

    def importar_produto(self, item):
        codigo = item.get("codigo_barras")
        nome = item.get("nome")
        if not codigo or not nome:
            raise ValueError("codigo_barras e nome são obrigatórios")
        if not item.get("preco_venda"):
            raise ValueError("preco_venda é obrigatório")

        id_categoria = None
        if item.get("categoria"):
            categoria = Categoria.query.filter_by(nome=item["categoria"]).first()
            if not categoria:
                categoria = Categoria(nome=item["categoria"], descricao=None)
                categoria.salvar()
            id_categoria = categoria.id_categoria

        produto = Produto.buscar_por_codigo(codigo)
        if produto:
            produto.atualizar(
                nome,
                id_categoria,
                codigo,
                numero(item.get("preco_custo")),
                numero(item.get("preco_venda")),
                inteiro(item.get("quantidade_estoque")) or 0,
                inteiro(item.get("estoque_minimo")) or 0,
                (item.get("unidade") or "UN").upper(),
                virar_data(item.get("data_validade")),
            )
            return "atualizado"

        produto = Produto(
            nome=nome,
            id_categoria=id_categoria,
            codigo_barras=codigo,
            preco_custo=numero(item.get("preco_custo")),
            preco_venda=numero(item.get("preco_venda")),
            quantidade_estoque=inteiro(item.get("quantidade_estoque")) or 0,
            estoque_minimo=inteiro(item.get("estoque_minimo")) or 0,
            unidade=(item.get("unidade") or "UN").upper(),
            data_validade=virar_data(item.get("data_validade")),
        )
        produto.salvar()
        return "criado"

    def importar_venda(self, item):
        produto = Produto.buscar_por_codigo(item.get("codigo_barras"))
        if not produto:
            raise ValueError("produto não encontrado")
        quantidade = inteiro(item.get("quantidade"))
        if not quantidade:
            raise ValueError("quantidade tem que ser maior que zero")
        data_venda = virar_data(item.get("data_venda")) or date.today()
        venda = Venda(id_produto=produto.id_produto, quantidade=quantidade, data_venda=data_venda)
        venda.salvar()
