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


def test_venda_nao_usa_o_lote_vencido_se_tem_lote_bom(client):
    leite = criar_produto("Leite")
    vencido = entrada(client, leite, 3, data_validade=dia(-1).isoformat())
    entrada(client, leite, 5, data_validade=dia(5).isoformat())
    client.post("/vendas", json={"id_produto": leite.id_produto, "quantidade": 4})
    assert Lote.buscar_por_id(vencido["id_lote"]).quantidade_atual == 3  # continua la pra ser retirado
