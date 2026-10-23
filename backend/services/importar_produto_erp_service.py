from math import isfinite

from models.categoria_model import Categoria
from models.database import db
from models.produto_model import Produto
from services.estoque_lote_service import EstoqueLoteService
from services.utils import inteiro, numero, virar_data


class ImportarProdutoErpService:
    def __init__(self, sincronizando=False, produto_model=None, categoria_model=None, estoque=None):
        self.sincronizando = sincronizando
        self.produto_model = produto_model if produto_model is not None else Produto
        self.categoria_model = categoria_model if categoria_model is not None else Categoria
        self.estoque = estoque if estoque is not None else EstoqueLoteService(origem_movimento="erp")

    @staticmethod
    def inteiro(valor):
        if isinstance(valor, (bool, float)):
            raise ValueError("valor precisa ser numero inteiro")
        return inteiro(valor) or 0

    @staticmethod
    def numero(valor):
        resultado = numero(valor)
        if resultado is not None and not isfinite(resultado):
            raise ValueError("valor precisa ser número finito")
        return resultado

    def executar(self, item):
        if not isinstance(item, dict):
            raise ValueError("formato inválido")
        codigo, nome = item.get("codigo_barras"), item.get("nome")
        if not codigo or not nome:
            raise ValueError("codigo_barras e nome são obrigatórios")
        if not item.get("preco_venda"):
            raise ValueError("preco_venda é obrigatório")
        produto = self.produto_model.buscar_por_codigo(codigo)
        preservar = produto is not None and self.sincronizando

        def campo(chave, converter, padrao):
            if preservar and chave not in item:
                return getattr(produto, chave)
            return converter(item.get(chave)) if chave in item else padrao

        campos = {"nome": nome, "codigo_barras": codigo,
                  "preco_venda": self.numero(item.get("preco_venda")),
                  "preco_custo": campo("preco_custo", self.numero, None),
                  "estoque_minimo": campo("estoque_minimo", self.inteiro, 0),
                  "unidade": campo("unidade", lambda v: (v or "UN").upper(), "UN")}
        quantidade = None if preservar and "quantidade_estoque" not in item else self.inteiro(item.get("quantidade_estoque"))
        validade = virar_data(item.get("data_validade"))
        origem = "erp" if self.sincronizando else "importacao"
        novo = produto is None
        try:
            id_categoria = produto.id_categoria if preservar else None
            if item.get("categoria"):
                nome_categoria = str(item["categoria"]).strip()
                categoria = self.categoria_model.buscar_por_nome(nome_categoria)
                if categoria is None:
                    categoria = self.categoria_model(nome=nome_categoria, descricao=None)
                    categoria.salvar(confirmar=False)
                id_categoria = categoria.id_categoria
            elif "categoria" in item:
                id_categoria = None
            campos["id_categoria"] = id_categoria
            if novo:
                produto = self.produto_model(**campos, quantidade_estoque=0)
                produto.salvar(confirmar=False)
                if quantidade > 0:
                    self.estoque.entrada(produto, quantidade, data_validade=validade, origem=origem, tipo="saldo_inicial")
            else:
                for chave, valor in campos.items():
                    setattr(produto, chave, valor)
                if quantidade is not None:
                    self.estoque.ajustar_para(produto, quantidade, data_validade=validade, origem=origem)
            produto.salvar()
        except Exception:
            db.session.rollback()
            raise
        return "criado" if novo else "atualizado"
