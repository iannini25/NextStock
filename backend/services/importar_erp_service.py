from datetime import date

from models.database import db
from models.produto_model import Produto
from models.categoria_model import Categoria
from models.erp_venda_importada_model import ErpVendaImportada
from services.registrar_venda_service import RegistrarVendaService
from services.utils import numero, inteiro, virar_data


class ImportarErpService:

    # modo "importacao" (padrao, usado pelo POST /erp/importar): igual sempre foi.
    # modo "sincronizacao" (quando o NextStock busca os dados no ERP):
    #   - o ERP manda o estoque atual, entao as vendas entram so como historico (nao baixam de novo)
    #   - campo que o ERP nao manda fica como esta no NextStock (ex.: estoque_minimo, validade)
    #   - cada venda precisa de id_externo e nunca entra duas vezes
    def __init__(self, modo="importacao"):
        self.sincronizando = modo == "sincronizacao"

    def executar(self, dados):
        produtos = dados.get("produtos") or []
        vendas = dados.get("vendas") or []
        if not produtos and not vendas:
            raise ValueError("manda pelo menos produtos ou vendas")
        return self.importar(produtos, vendas)

    # na sincronizacao pode vir tudo vazio (nada mudou no ERP desde a ultima vez)
    def importar(self, produtos, vendas):
        criados = 0
        atualizados = 0
        importadas = 0
        repetidas = 0
        erros = []

        for item in produtos:
            try:
                resultado = self.importar_produto(item)
                if resultado == "criado":
                    criados += 1
                else:
                    atualizados += 1
            except ValueError as e:
                erros.append("produto " + self.identificar(item, "codigo_barras") + ": " + str(e))

        for item in vendas:
            try:
                if self.importar_venda(item) == "repetida":
                    repetidas += 1
                else:
                    importadas += 1
            except ValueError as e:
                chave = "id_externo" if self.sincronizando else "codigo_barras"
                erros.append("venda " + self.identificar(item, chave) + ": " + str(e))

        resultado = {
            "produtos_criados": criados,
            "produtos_atualizados": atualizados,
            "vendas_importadas": importadas,
            "erros": erros,
        }
        if self.sincronizando:
            resultado["vendas_ja_importadas"] = repetidas
        return resultado

    @staticmethod
    def identificar(item, chave):
        return str(item.get(chave)) if isinstance(item, dict) else "?"

    def importar_produto(self, item):
        if not isinstance(item, dict):
            raise ValueError("formato inválido")
        codigo = item.get("codigo_barras")
        nome = item.get("nome")
        if not codigo or not nome:
            raise ValueError("codigo_barras e nome são obrigatórios")
        if not item.get("preco_venda"):
            raise ValueError("preco_venda é obrigatório")

        id_categoria = None
        if item.get("categoria"):
            categoria = Categoria.buscar_por_nome(str(item["categoria"]))
            if not categoria:
                categoria = Categoria(nome=str(item["categoria"]).strip(), descricao=None)
                categoria.salvar()
            id_categoria = categoria.id_categoria

        produto = Produto.buscar_por_codigo(codigo)
        if produto and self.sincronizando:
            # so troca o que o ERP mandou
            def campo(chave, converter, atual):
                return converter(item.get(chave)) if chave in item else atual

            produto.atualizar(
                nome,
                id_categoria if "categoria" in item else produto.id_categoria,
                codigo,
                campo("preco_custo", numero, produto.preco_custo),
                numero(item.get("preco_venda")),
                campo("quantidade_estoque", lambda v: inteiro(v) or 0, produto.quantidade_estoque),
                campo("estoque_minimo", lambda v: inteiro(v) or 0, produto.estoque_minimo),
                campo("unidade", lambda v: (v or "UN").upper(), produto.unidade),
                campo("data_validade", virar_data, produto.data_validade),
            )
            return "atualizado"
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
        if not isinstance(item, dict):
            raise ValueError("formato inválido")
        id_externo = None
        if self.sincronizando:
            id_externo = str(item.get("id_externo") or "").strip()
            if not id_externo:
                raise ValueError("venda sem id_externo")
            if len(id_externo) > 100:
                raise ValueError("id_externo pode ter no máximo 100 caracteres")
            if ErpVendaImportada.ja_importada(id_externo):
                return "repetida"

        produto = Produto.buscar_por_codigo(item.get("codigo_barras"))
        if not produto:
            raise ValueError("produto não encontrado")
        quantidade = inteiro(item.get("quantidade"))
        if not quantidade:
            raise ValueError("quantidade tem que ser maior que zero")
        data_venda = virar_data(item.get("data_venda")) or date.today()
        venda = RegistrarVendaService().executar({
            "id_produto": produto.id_produto,
            "quantidade": quantidade,
            "data_venda": data_venda.isoformat(),
        }, baixar_estoque=not self.sincronizando)

        if self.sincronizando:
            db.session.add(ErpVendaImportada(id_externo=id_externo, id_venda=venda["id_venda"]))
            db.session.commit()
        return "importada"
