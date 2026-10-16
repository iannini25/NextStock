import pytest

from models.lote_model import Lote
from models.movimentacao_estoque_model import MovimentacaoEstoque
from models.produto_model import Produto
from models.database import db
from services.estoque_lote_service import ordenar_lotes_para_saida, planejar_saida
from tests.fabricas import criar_produto, dia


def entrada(client, produto, quantidade, **extra):
    return client.post("/lotes", json={"id_produto": produto.id_produto, "quantidade": quantidade, **extra}).get_json()["lote"]


def previa(client, produto, quantidade):
    r = client.get("/vendas/previa", query_string={"id_produto": produto.id_produto, "quantidade": quantidade})
    assert r.status_code == 200, r.get_json()
    return r.get_json()


# ---------- regra da ordem de saida ----------

def test_ordem_validades_diferentes_iguais_e_vazias():
    a = Lote(id_lote=1, data_validade=dia(10), data_entrada=dia(-5))
    b = Lote(id_lote=2, data_validade=dia(3), data_entrada=dia(-1))
    c = Lote(id_lote=3, data_validade=None, data_entrada=dia(-9))
    d = Lote(id_lote=4, data_validade=dia(3), data_entrada=dia(-4))  # mesma validade de b, entrou antes
    assert [l.id_lote for l in ordenar_lotes_para_saida([a, b, c, d])] == [4, 2, 1, 3]


def test_lote_vencido_vai_pro_fim_da_fila():
    vencido = Lote(id_lote=1, data_validade=dia(-2), data_entrada=dia(-20))
    bom = Lote(id_lote=2, data_validade=dia(5), data_entrada=dia(-1))
    sem_validade = Lote(id_lote=3, data_validade=None, data_entrada=dia(-1))
    assert [l.id_lote for l in ordenar_lotes_para_saida([vencido, bom, sem_validade])] == [2, 3, 1]


def test_planejar_nao_mexe_nos_lotes():
    a = Lote(id_lote=1, data_validade=dia(2), quantidade_atual=4, data_entrada=dia(-1))
    b = Lote(id_lote=2, data_validade=dia(9), quantidade_atual=10, data_entrada=dia(-1))
    plano, falta = planejar_saida([b, a], 6)
    assert [(l.id_lote, q) for l, q in plano] == [(1, 4), (2, 2)]
    assert falta == 0
    assert (a.quantidade_atual, b.quantidade_atual) == (4, 10)
    assert planejar_saida([a], 9)[1] == 5  # faltam 5


# ---------- ordem de saida na API ----------

def test_ordem_de_saida_com_selo_vender_primeiro(client):
    leite = criar_produto("Leite", quantidade_estoque=5)  # lote sem validade
    entrada(client, leite, 3, data_validade=dia(-1).isoformat(), codigo_lote="VENC")
    entrada(client, leite, 4, data_validade=dia(2).isoformat(), codigo_lote="PERTO")
    entrada(client, leite, 6, data_validade=dia(20).isoformat(), codigo_lote="LONGE")

    r = client.get(f"/produtos/{leite.id_produto}/ordem-saida")
    assert r.status_code == 200
    lotes = r.get_json()["lotes"]
    assert [(l["titulo"], l["posicao_saida"], l["vender_primeiro"]) for l in lotes] == [
        ("Lote PERTO", 1, True),
        ("Lote LONGE", 2, False),
        ("Lote #1", 3, False),
        ("Lote VENC", 4, False),  # vencido: retirar, nunca vender primeiro
    ]
    assert client.get("/produtos/999/ordem-saida").status_code == 404


def test_lista_de_lotes_tambem_traz_a_ordem(client):
    leite = criar_produto("Leite", quantidade_estoque=5, data_validade=dia(9))
    entrada(client, leite, 2, data_validade=dia(1).isoformat())
    lotes = client.get(f"/produtos/{leite.id_produto}/lotes").get_json()["lotes"]
    assert [(l["posicao_saida"], l["vender_primeiro"]) for l in lotes] == [(1, True), (2, False)]


def test_so_lotes_vencidos_ninguem_ganha_o_selo(client):
    leite = criar_produto("Leite")
    entrada(client, leite, 3, data_validade=dia(-1).isoformat())
    lotes = client.get(f"/produtos/{leite.id_produto}/ordem-saida").get_json()["lotes"]
    assert [l["vender_primeiro"] for l in lotes] == [False]


# ---------- previa da venda ----------

def test_previa_mostra_de_quais_lotes_a_venda_sai(client):
    leite = criar_produto("Leite", quantidade_estoque=10, data_validade=dia(20))
    entrada(client, leite, 5, data_validade=dia(2).isoformat(), codigo_lote="L1")
    p = previa(client, leite, 8)
    assert p["suficiente"] is True
    assert p["falta"] == 0
    assert p["aviso"] is None
    assert [(l["titulo"], l["quantidade"], l["dias_para_vencer"]) for l in p["lotes"]] == [
        ("Lote L1", 5, 2),
        ("Lote #1", 3, 20),
    ]


def test_previa_nao_grava_nada(client):
    leite = criar_produto("Leite", quantidade_estoque=10)
    antes = (MovimentacaoEstoque.query.count(), Lote.query.one().quantidade_atual)
    previa(client, leite, 4)
    assert (MovimentacaoEstoque.query.count(), Lote.query.one().quantidade_atual) == antes
    assert Produto.buscar_por_id(leite.id_produto).quantidade_estoque == 10


def test_previa_e_igual_a_baixa_de_verdade(client):
    leite = criar_produto("Leite", quantidade_estoque=4, data_validade=dia(30))
    entrada(client, leite, 3, data_validade=dia(1).isoformat())
    entrada(client, leite, 6, data_validade=dia(8).isoformat())
    prevista = [(l["id_lote"], l["quantidade"]) for l in previa(client, leite, 11)["lotes"]]

    venda = client.post("/vendas", json={"id_produto": leite.id_produto, "quantidade": 11}).get_json()
    consumida = [(l["id_lote"], l["quantidade"]) for l in venda["lotes_consumidos"]]
    no_historico = [(m.id_lote, m.quantidade) for m in
                    MovimentacaoEstoque.query.filter_by(id_venda=venda["id_venda"]).order_by(MovimentacaoEstoque.id_movimentacao)]
    assert prevista == consumida == no_historico


def test_previa_sem_estoque_suficiente(client):
    leite = criar_produto("Leite", quantidade_estoque=3)
    p = previa(client, leite, 5)
    assert (p["suficiente"], p["falta"]) == (False, 2)
    assert [l["quantidade"] for l in p["lotes"]] == [3]


def test_previa_avisa_quando_vai_sair_de_lote_vencido(client):
    leite = criar_produto("Leite")
    entrada(client, leite, 2, data_validade=dia(5).isoformat())
    entrada(client, leite, 3, data_validade=dia(-1).isoformat())
    assert previa(client, leite, 2)["aviso"] is None  # o lote bom da conta
    p = previa(client, leite, 4)
    assert p["lotes"][-1]["vencido"] is True
    assert p["aviso"].startswith("parte da venda sairia de lote vencido")


def test_venda_nao_usa_o_lote_vencido_se_tem_lote_bom(client):
    leite = criar_produto("Leite")
    vencido = entrada(client, leite, 3, data_validade=dia(-1).isoformat())
    entrada(client, leite, 5, data_validade=dia(5).isoformat())
    client.post("/vendas", json={"id_produto": leite.id_produto, "quantidade": 4})
    assert Lote.buscar_por_id(vencido["id_lote"]).quantidade_atual == 3  # continua la pra ser retirado


def test_previa_de_produto_antigo_sem_lote(client):
    p = Produto(nome="Antigo", preco_venda=5, quantidade_estoque=6)
    db.session.add(p)
    db.session.commit()
    resultado = previa(client, p, 4)
    assert resultado["suficiente"] is True
    assert resultado["lotes"][0]["titulo"] == "Estoque inicial"
    assert Lote.query.count() == 0  # previa nao cria nada


@pytest.mark.parametrize("query, erro", [
    ({"id_produto": 999, "quantidade": 1}, "produto não existe"),
    ({"quantidade": 1}, "produto não existe"),
])
def test_previa_produto_invalido(client, query, erro):
    r = client.get("/vendas/previa", query_string=query)
    assert r.status_code == 400
    assert r.get_json() == {"erro": erro}


def test_previa_quantidade_invalida(client):
    leite = criar_produto("Leite", quantidade_estoque=3)
    r = client.get("/vendas/previa", query_string={"id_produto": leite.id_produto, "quantidade": 0})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "quantidade tem que ser maior que zero"}


# ---------- venda e recomendacoes ----------

def test_venda_responde_os_lotes_consumidos(client):
    leite = criar_produto("Leite", quantidade_estoque=2, data_validade=dia(9))
    entrada(client, leite, 3, data_validade=dia(4).isoformat(), codigo_lote="A")
    venda = client.post("/vendas", json={"id_produto": leite.id_produto, "quantidade": 4}).get_json()
    assert [(l["titulo"], l["quantidade"]) for l in venda["lotes_consumidos"]] == [("Lote A", 3), ("Lote #1", 1)]
    assert venda["quantidade"] == 4  # o resto da resposta continua igual


def test_recomendacao_de_validade_fala_do_lote_e_nao_do_estoque_inteiro(client):
    queijo = criar_produto("Queijo", quantidade_estoque=10, data_validade=dia(20))
    vencido = entrada(client, queijo, 5, data_validade=dia(-1).isoformat(), codigo_lote="V1")
    perto = entrada(client, queijo, 4, data_validade=dia(2).isoformat(), codigo_lote="P1")

    recs = {r["tipo"]: r for r in client.get("/recomendacoes").get_json() if r["produto_nome"] == "Queijo"}
    assert recs["retirar"]["mensagem"] == "Lote V1 vencido com 5 em estoque: tire da prateleira"
    assert recs["retirar"]["id_lote"] == vencido["id_lote"]
    assert recs["promocao"]["mensagem"] == (
        "Lote P1 vence em 2 dia(s) com 4 em estoque: venda primeiro e faça promoção (deixe o lote mais novo pra depois)"
    )
    assert recs["promocao"]["id_lote"] == perto["id_lote"]


def test_recomendacoes_sem_validade_nao_tem_lote(client):
    criar_produto("Parado", quantidade_estoque=5)
    rec = next(r for r in client.get("/recomendacoes").get_json() if r["tipo"] == "produto_parado")
    assert rec["id_lote"] is None
