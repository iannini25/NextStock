"""Limpa e recria dados de demonstracao no SQLite."""
from datetime import date, timedelta

from app import app
from models.database import db
from models.categoria_model import Categoria
from models.produto_model import Produto
from models.venda_model import Venda
from models.evento_model import Evento

hoje = date.today()


def limpar():
    Venda.query.delete()
    Produto.query.delete()
    Evento.query.delete()
    Categoria.query.delete()
    db.session.commit()


def criar_categorias():
    nomes = [
        ("Hortifruti", "Frutas, legumes e verduras"),
        ("Laticínios", "Leite, queijos e iogurtes"),
        ("Padaria", "Pães, bolos e salgados"),
        ("Açougue", "Carnes e aves"),
        ("Bebidas", "Sucos, água e refrigerantes"),
        ("Frios", "Presunto, queijos fatiados e embutidos"),
    ]
    cats = []
    for nome, desc in nomes:
        c = Categoria(nome=nome, descricao=desc)
        db.session.add(c)
        cats.append(c)
    db.session.flush()
    return cats


def criar_produtos(cats):
    h, l, p, a, b, f = cats
    itens = [
        # hortifruti: validade curta + um em ruptura
        (h, "Banana Prata (kg)", "7891000000017", 3.50, 5.99, 38, 10, "KG", hoje + timedelta(days=2)),
        (h, "Alface Crespa (un)", "7891000000024", 1.20, 2.99, 5, 12, "UN", hoje + timedelta(days=1)),
        (h, "Tomate Italiano (kg)", "7891000000031", 4.10, 7.49, 22, 8, "KG", hoje + timedelta(days=4)),
        (h, "Maçã Gala (kg)", "7891000000048", 5.20, 8.90, 45, 12, "KG", hoje + timedelta(days=12)),
        # laticinios: iogurte vencendo e abaixo do minimo
        (l, "Leite Integral 1L", "7891000000116", 3.20, 4.79, 96, 30, "UN", hoje + timedelta(days=28)),
        (l, "Iogurte Natural 170g", "7891000000123", 1.80, 3.50, 6, 20, "UN", hoje + timedelta(days=3)),
        (l, "Queijo Minas 400g", "7891000000130", 9.40, 16.90, 18, 8, "UN", hoje + timedelta(days=10)),
        # padaria
        (p, "Pão Francês (kg)", "7891000000215", 8.00, 14.90, 14, 6, "KG", None),
        (p, "Bolo de Cenoura (un)", "7891000000222", 7.50, 14.00, 4, 5, "UN", hoje + timedelta(days=2)),
        # acougue
        (a, "Carne Moída (kg)", "7891000000314", 22.00, 34.90, 16, 8, "KG", hoje + timedelta(days=3)),
        (a, "Frango Inteiro (kg)", "7891000000321", 8.80, 14.50, 7, 10, "KG", hoje + timedelta(days=4)),
        # bebidas: agua parada (muito estoque, pouca venda)
        (b, "Suco de Laranja 1L", "7891000000413", 3.90, 7.49, 40, 15, "UN", hoje + timedelta(days=20)),
        (b, "Água Mineral 1,5L", "7891000000420", 1.10, 2.49, 180, 20, "UN", hoje + timedelta(days=180)),
        # frios
        (f, "Presunto Fatiado 200g", "7891000000512", 6.20, 11.90, 9, 10, "UN", hoje + timedelta(days=6)),
        (f, "Mussarela Fatiada 200g", "7891000000529", 7.10, 13.50, 21, 8, "UN", hoje + timedelta(days=8)),
    ]
    prods = []
    for cat, nome, cod, custo, venda, qtd, minimo, un, val in itens:
        pr = Produto(
            id_categoria=cat.id_categoria,
            nome=nome,
            codigo_barras=cod,
            preco_custo=custo,
            preco_venda=venda,
            quantidade_estoque=qtd,
            estoque_minimo=minimo,
            unidade=un,
            data_validade=val,
        )
        db.session.add(pr)
        prods.append(pr)
    db.session.flush()
    return {p.nome: p for p in prods}


def criar_vendas(mapa):
    # (nome, qtd, dias_atras)
    historico = []

    def serie(nome, pares):
        for qtd, dias in pares:
            historico.append((nome, qtd, dias))

    # leite: vende quase todo dia
    serie("Leite Integral 1L", [
        (14, 1), (11, 2), (13, 3), (10, 4), (12, 5), (15, 6), (9, 8),
        (12, 9), (11, 10), (14, 11), (10, 13), (13, 14), (12, 16), (11, 18),
        (15, 20), (10, 22), (12, 24), (13, 27), (11, 29), (9, 35),
    ])
    # banana: mais no fim de semana
    serie("Banana Prata (kg)", [
        (9, 2), (11, 3), (6, 6), (10, 9), (12, 10), (5, 13), (9, 16),
        (11, 17), (7, 20), (10, 23), (8, 27),
    ])
    # pao
    serie("Pão Francês (kg)", [
        (7, 1), (8, 2), (6, 5), (9, 6), (4, 8), (7, 12), (8, 13),
        (6, 19), (7, 20), (5, 26),
    ])
    # iogurte: pouca venda (estoque parado + vencendo)
    serie("Iogurte Natural 170g", [(2, 2), (1, 8), (2, 15), (1, 22)])
    # alface
    serie("Alface Crespa (un)", [(3, 1), (2, 4), (3, 9), (2, 16)])
    # tomate
    serie("Tomate Italiano (kg)", [(5, 2), (6, 6), (4, 11), (5, 18), (6, 25)])
    # maca
    serie("Maçã Gala (kg)", [(4, 3), (5, 7), (3, 14), (4, 21)])
    # queijo
    serie("Queijo Minas 400g", [(2, 2), (3, 9), (2, 16), (3, 23)])
    # bolo
    serie("Bolo de Cenoura (un)", [(1, 1), (2, 8), (1, 15)])
    # carne
    serie("Carne Moída (kg)", [(4, 1), (5, 5), (3, 8), (4, 12), (5, 19)])
    # frango
    serie("Frango Inteiro (kg)", [(3, 2), (4, 6), (2, 13), (3, 20)])
    # suco
    serie("Suco de Laranja 1L", [(6, 1), (5, 4), (7, 8), (4, 15), (6, 22)])
    # agua: quase nada (produto parado)
    serie("Água Mineral 1,5L", [(2, 18), (1, 40)])
    # frios
    serie("Presunto Fatiado 200g", [(3, 2), (2, 7), (3, 14), (2, 21)])
    serie("Mussarela Fatiada 200g", [(4, 1), (3, 8), (4, 15), (3, 22)])

    for nome, qtd, dias in historico:
        p = mapa[nome]
        db.session.add(Venda(
            id_produto=p.id_produto,
            quantidade=qtd,
            data_venda=hoje - timedelta(days=dias),
        ))


def criar_eventos():
    db.session.add(Evento(
        nome="Feriado prolongado",
        data_inicio=hoje - timedelta(days=18),
        data_fim=hoje - timedelta(days=16),
        impacto_percentual=20,
    ))
    db.session.add(Evento(
        nome="Feira gastronômica do bairro",
        data_inicio=hoje + timedelta(days=2),
        data_fim=hoje + timedelta(days=4),
        impacto_percentual=35,
    ))


with app.app_context():
    db.create_all()
    limpar()
    cats = criar_categorias()
    mapa = criar_produtos(cats)
    criar_vendas(mapa)
    criar_eventos()
    db.session.commit()
    print(
        "demo ok:",
        Categoria.query.count(), "categorias,",
        Produto.query.count(), "produtos,",
        Venda.query.count(), "vendas,",
        Evento.query.count(), "eventos",
    )
