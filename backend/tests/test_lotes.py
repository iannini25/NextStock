from datetime import date

import pytest

from models.database import db
from models.lote_model import Lote
from models.produto_model import Produto
from services.estoque_lote_service import ordenar_lotes_para_saida
from tests.fabricas import criar_produto, dia


def conferir_invariante():
    # regra central: o estoque de todo produto e exatamente a soma dos saldos dos lotes
    for p in Produto.query.all():
        soma = sum(l.quantidade_atual for l in Lote.query.filter_by(id_produto=p.id_produto))
        assert p.quantidade_estoque == soma, f"{p.nome}: estoque {p.quantidade_estoque} != lotes {soma}"


def lotes(client, produto, todos=False):
    r = client.get(f"/produtos/{produto.id_produto}/lotes" + ("?todos=1" if todos else ""))
    assert r.status_code == 200
    return r.get_json()["lotes"]


def entrada(client, produto, quantidade, **extra):
    return client.post("/lotes", json={"id_produto": produto.id_produto, "quantidade": quantidade, **extra})


def produto_atual(client, produto):
    return client.get(f"/produtos/{produto.id_produto}").get_json()


# ---------- migracao ----------

def test_entrada_cria_lote_e_soma_no_estoque(client):
    leite = criar_produto("Leite", quantidade_estoque=5, data_validade=dia(10), preco_custo=3)
    r = entrada(client, leite, 20, data_validade=dia(4).isoformat(), codigo_lote="L-778", custo_unitario="3.40")
    assert r.status_code == 201
    corpo = r.get_json()
    assert corpo["lote"]["quantidade_atual"] == 20
    assert corpo["lote"]["codigo_lote"] == "L-778"
    assert corpo["lote"]["custo_unitario"] == 3.4
    assert corpo["lote"]["origem"] == "entrada"
    assert corpo["lote"]["usuario"] == "Admin"
    assert corpo["lote"]["dias_para_vencer"] == 4
    assert corpo["produto"]["quantidade_estoque"] == 25
    assert corpo["produto"]["data_validade"] == dia(4).isoformat()  # a menor validade entre os lotes
    conferir_invariante()


def test_venda_tira_primeiro_do_lote_que_vence_antes_e_atravessa_lotes(client):
    leite = criar_produto("Leite", quantidade_estoque=5, data_validade=dia(10))
    entrada(client, leite, 10, data_validade=dia(3).isoformat())
    r = client.post("/vendas", json={"id_produto": leite.id_produto, "quantidade": 12})
    assert r.status_code == 201

    saldos = {l["data_validade"]: l["quantidade_atual"] for l in lotes(client, leite, todos=True)}
    assert saldos == {dia(3).isoformat(): 0, dia(10).isoformat(): 3}
    p = produto_atual(client, leite)
    assert p["quantidade_estoque"] == 3
    assert p["data_validade"] == dia(10).isoformat()  # o lote que acabou nao conta mais
    conferir_invariante()


def test_lote_sem_validade_sai_por_ultimo(client):
    arroz = criar_produto("Arroz", quantidade_estoque=4)  # lote inicial sem validade
    entrada(client, arroz, 4, data_validade=dia(60).isoformat())
    client.post("/vendas", json={"id_produto": arroz.id_produto, "quantidade": 3})
    saldos = {l["data_validade"]: l["quantidade_atual"] for l in lotes(client, arroz)}
    assert saldos == {dia(60).isoformat(): 1, None: 4}


def test_venda_sem_estoque_suficiente_nao_mexe_em_nada(client):
    leite = criar_produto("Leite", quantidade_estoque=5)
    entrada(client, leite, 3)
    r = client.post("/vendas", json={"id_produto": leite.id_produto, "quantidade": 9})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "estoque insuficiente"}
    assert sorted(l["quantidade_atual"] for l in lotes(client, leite)) == [3, 5]
    conferir_invariante()


def test_lotes_vencendo(client):
    queijo = criar_produto("Queijo", quantidade_estoque=10, data_validade=dia(20))
    entrada(client, queijo, 4, data_validade=dia(-2).isoformat())
    entrada(client, queijo, 6, data_validade=dia(3).isoformat())
    acabou = criar_produto("Acabou")
    entrada(client, acabou, 1, data_validade=dia(1).isoformat())
    client.post("/vendas", json={"id_produto": acabou.id_produto, "quantidade": 1})  # sem saldo: nao aparece

    r = client.get("/lotes/vencendo?dias=7")
    assert r.status_code == 200
    assert [(l["produto_nome"], l["quantidade_atual"], l["vencido"]) for l in r.get_json()] == [
        ("Queijo", 4, True),
        ("Queijo", 6, False),
    ]
    assert len(client.get("/lotes/vencendo?dias=30").get_json()) == 3
    assert client.get("/lotes/vencendo?dias=400").status_code == 400


# ---------- consultar e corrigir lotes ----------

def test_corrigir_validade_atualiza_a_validade_do_produto(client):
    leite = criar_produto("Leite", quantidade_estoque=5, data_validade=dia(10))
    lote = Lote.query.one()
    r = client.put(f"/lotes/{lote.id_lote}", json={"codigo_lote": "ABC", "data_validade": dia(2).isoformat()})
    assert r.status_code == 200
    assert r.get_json()["lote"]["codigo_lote"] == "ABC"
    assert r.get_json()["lote"]["quantidade_atual"] == 5  # quantidade nao muda por aqui
    assert produto_atual(client, leite)["data_validade"] == dia(2).isoformat()
