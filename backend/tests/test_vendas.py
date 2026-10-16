from datetime import date

import pytest

from models.venda_model import Venda
from tests.fabricas import criar_produto, criar_venda


def estoque(client, produto):
    return client.get(f"/produtos/{produto.id_produto}").get_json()["quantidade_estoque"]


def test_registra_venda_e_baixa_estoque(client):
    p = criar_produto("Leite", quantidade_estoque=10, preco_venda=5)
    r = client.post("/vendas", json={"id_produto": p.id_produto, "quantidade": 3})
    assert r.status_code == 201
    v = r.get_json()
    assert v["quantidade"] == 3
    assert v["produto_nome"] == "Leite"
    assert v["valor_total"] == 15.0
    assert v["data_venda"] == date.today().isoformat()
    assert estoque(client, p) == 7


def test_registra_venda_com_data(client):
    p = criar_produto("Leite", quantidade_estoque=10)
    r = client.post("/vendas", json={"id_produto": p.id_produto, "quantidade": 1, "data_venda": "2026-01-10"})
    assert r.status_code == 201
    assert r.get_json()["data_venda"] == "2026-01-10"


def test_nao_vende_mais_que_o_estoque(client):
    p = criar_produto("Leite", quantidade_estoque=2)
    r = client.post("/vendas", json={"id_produto": p.id_produto, "quantidade": 3})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "estoque insuficiente"}
    assert estoque(client, p) == 2
    assert Venda.query.count() == 0


@pytest.mark.parametrize("extra, erro", [
    ({"quantidade": 0}, "quantidade tem que ser maior que zero"),
    ({}, "quantidade tem que ser maior que zero"),
    ({"quantidade": -2}, "valor nao pode ser negativo"),
    ({"quantidade": 1, "data_venda": "10/01/2026"}, "data tem que ser aaaa-mm-dd"),
])
def test_venda_invalida(client, extra, erro):
    p = criar_produto("Leite", quantidade_estoque=10)
    r = client.post("/vendas", json={"id_produto": p.id_produto, **extra})
    assert r.status_code == 400
    assert r.get_json() == {"erro": erro}


@pytest.mark.parametrize("dados", [{}, {"id_produto": 999, "quantidade": 1}])
def test_venda_de_produto_inexistente(client, dados):
    r = client.post("/vendas", json=dados)
    assert r.status_code == 400
    assert r.get_json() == {"erro": "produto não existe"}


def test_lista_vendas_do_periodo_mais_recente_primeiro(client):
    p = criar_produto("Leite")
    criar_venda(p, 1, dias_atras=10)
    criar_venda(p, 2, dias_atras=5)
    criar_venda(p, 3, dias_atras=40)

    padrao = client.get("/vendas").get_json()
    assert [v["quantidade"] for v in padrao] == [2, 1]

    sessenta = client.get("/vendas?dias=60").get_json()
    assert [v["quantidade"] for v in sessenta] == [2, 1, 3]


def test_lista_vendas_dias_invalido(client):
    r = client.get("/vendas?dias=0")
    assert r.status_code == 400
    assert r.get_json() == {"erro": "dias tem que ser entre 1 e 365"}
