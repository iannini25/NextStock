from datetime import date, timedelta

from models.database import db
from models.categoria_model import Categoria
from models.clima_model import ClimaDia
from models.empresa_model import Empresa
from models.evento_model import Evento
from models.produto_model import Produto
from models.usuario_model import Usuario
from models.venda_model import Venda


# data relativa a hoje: dia(-1) = ontem, dia(2) = depois de amanha
def dia(n):
    return date.today() + timedelta(days=n)


def criar_categoria(nome="Laticínios", descricao=None):
    c = Categoria(nome=nome, descricao=descricao)
    db.session.add(c)
    db.session.commit()
    return c


def criar_produto(nome="Leite Integral 1L", **campos):
    dados = {
        "preco_custo": 3.0,
        "preco_venda": 5.0,
        "quantidade_estoque": 0,
        "estoque_minimo": 0,
        "unidade": "UN",
    }
    dados.update(campos)
    p = Produto(nome=nome, **dados)
    db.session.add(p)
    db.session.commit()
    return p


# grava a venda direto na tabela, sem baixar estoque (so pra montar historico)
def criar_venda(produto, quantidade, dias_atras=1):
    v = Venda(id_produto=produto.id_produto, quantidade=quantidade, data_venda=dia(-dias_atras))
    db.session.add(v)
    db.session.commit()
    return v


# uma venda por dia, de `de` ate `ate` dias atras.
# de 1 a 28 cobre cada dia da semana 4 vezes, entao a previsao fica exatamente `quantidade` por dia
def criar_vendas_diarias(produto, quantidade, de=1, ate=28):
    for d in range(de, ate + 1):
        db.session.add(Venda(id_produto=produto.id_produto, quantidade=quantidade, data_venda=dia(-d)))
    db.session.commit()


def criar_evento(nome="Festa do bairro", inicio=1, fim=2, impacto=0):
    e = Evento(nome=nome, data_inicio=dia(inicio), data_fim=dia(fim), impacto_percentual=impacto)
    db.session.add(e)
    db.session.commit()
    return e


def criar_clima(dias_daqui, condicao, temperatura=22.0, chuva_mm=0.0):
    c = ClimaDia(data=dia(dias_daqui), temperatura=temperatura, chuva_mm=chuva_mm, condicao=condicao)
    db.session.add(c)
    db.session.commit()
    return c


def criar_empresa(nome="Mercado Bom Preço LTDA", **campos):
    e = Empresa(nome=nome, **campos)
    db.session.add(e)
    db.session.commit()
    return e


SENHA_PADRAO = "senha1234"
_hash_senha_padrao = None


# cria a empresa junto se ela ainda nao existir
def criar_usuario(nome="Maria", email="maria@loja.com", senha=SENHA_PADRAO, perfil="usuario", ativo=True):
    global _hash_senha_padrao
    empresa = Empresa.buscar_unica() or criar_empresa()
    u = Usuario(id_empresa=empresa.id_empresa, nome=nome, email=email, perfil=perfil, ativo=ativo)
    if senha == SENHA_PADRAO:
        # gerar hash e lento de proposito; a senha padrao e calculada uma vez so pra suite toda
        if _hash_senha_padrao is None:
            u.definir_senha(senha)
            _hash_senha_padrao = u.senha_hash
        u.senha_hash = _hash_senha_padrao
    else:
        u.definir_senha(senha)
    db.session.add(u)
    db.session.commit()
    return u
