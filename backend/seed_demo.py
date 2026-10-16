"""Limpa e deixa só 1 categoria e 2 produtos para demonstração."""
from datetime import date, timedelta

from sqlalchemy import text

from app import app
from models.database import db
from models.categoria_model import Categoria
from models.produto_model import Produto
from models.venda_model import Venda
from models.evento_model import Evento
from models.erp_venda_importada_model import ErpVendaImportada
from models.lote_model import Lote
from models.movimentacao_estoque_model import MovimentacaoEstoque
from models.perda_model import Perda
from services.estoque_lote_service import criar_lotes_iniciais
from services.registrar_venda_service import RegistrarVendaService

hoje = date.today()


def limpar():
    Perda.query.delete()  # aponta pra produtos, lotes e historico: sai antes de todos
    MovimentacaoEstoque.query.delete()  # aponta pra produtos, lotes e vendas: sai primeiro
    ErpVendaImportada.query.delete()  # aponta pras vendas, sai antes delas
    Venda.query.delete()
    Lote.query.delete()  # aponta pros produtos, sai antes deles
    Produto.query.delete()
    Evento.query.delete()
    Categoria.query.delete()
    db.session.commit()
    if db.engine.dialect.name == "sqlite":
        try:
            db.session.execute(text("DELETE FROM sqlite_sequence"))
            db.session.commit()
        except Exception:
            db.session.rollback()


def criar():
    hortifruti = Categoria(nome="Hortifruti", descricao="Frutas, legumes e verduras")
    db.session.add(hortifruti)
    db.session.flush()

    banana = Produto(
        id_categoria=hortifruti.id_categoria,
        nome="Banana Prata (kg)",
        codigo_barras="7891000000017",
        preco_custo=3.50,
        preco_venda=5.99,
        quantidade_estoque=16,
        estoque_minimo=8,
        unidade="KG",
        data_validade=hoje + timedelta(days=2),
    )
    leite = Produto(
        id_categoria=hortifruti.id_categoria,
        nome="Leite Integral 1L",
        codigo_barras="7891000000116",
        preco_custo=3.20,
        preco_venda=4.79,
        quantidade_estoque=24,
        estoque_minimo=10,
        unidade="UN",
        data_validade=hoje + timedelta(days=28),
    )
    db.session.add(banana)
    db.session.add(leite)
    db.session.flush()

    db.session.add(Evento(
        nome="Feira do bairro",
        data_inicio=hoje + timedelta(days=2),
        data_fim=hoje + timedelta(days=4),
        impacto_percentual=25,
    ))
    db.session.commit()
    criar_lotes_iniciais()  # o estoque dos produtos de demonstracao vira o primeiro lote

    RegistrarVendaService().executar({
        "id_produto": banana.id_produto,
        "quantidade": 2,
        "data_venda": (hoje - timedelta(days=1)).isoformat(),
    })
    RegistrarVendaService().executar({
        "id_produto": leite.id_produto,
        "quantidade": 3,
        "data_venda": (hoje - timedelta(days=2)).isoformat(),
    })


with app.app_context():
    db.create_all()
    limpar()
    criar()
    print(
        "demo ok:",
        Categoria.query.count(), "categoria,",
        Produto.query.count(), "produtos,",
        Venda.query.count(), "vendas,",
        Evento.query.count(), "evento",
    )
