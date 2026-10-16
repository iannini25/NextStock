import pytest

from tests.fabricas import criar_categoria, criar_produto, criar_venda


def test_relatorio_de_consumo(client):
    cat = criar_categoria("Laticínios")
    leite = criar_produto("Leite", preco_venda=5, id_categoria=cat.id_categoria)
    queijo = criar_produto("Queijo", preco_venda=10)
    criar_venda(leite, 4, dias_atras=2)
    criar_venda(leite, 2, dias_atras=10)
    criar_venda(leite, 50, dias_atras=40)  # fora do periodo
    criar_venda(queijo, 2, dias_atras=3)

    r = client.get("/relatorios/consumo")
    assert r.status_code == 200
    rel = r.get_json()
    assert rel["dias"] == 30
    assert rel["total_vendido"] == 8
    assert rel["faturamento_total"] == 50.0
    assert rel["itens"] == [
        {"id_produto": leite.id_produto, "produto_nome": "Leite", "categoria_nome": "Laticínios",
         "quantidade_vendida": 6, "faturamento": 30.0, "percentual_do_total": 75.0},
        {"id_produto": queijo.id_produto, "produto_nome": "Queijo", "categoria_nome": None,
         "quantidade_vendida": 2, "faturamento": 20.0, "percentual_do_total": 25.0},
    ]


def test_relatorio_de_desempenho(client):
    leite = criar_produto("Leite", preco_custo=3, preco_venda=5)
    queijo = criar_produto("Queijo", preco_custo=5, preco_venda=10)
    criar_produto("Parado", preco_custo=None, preco_venda=8)
    criar_venda(leite, 6, dias_atras=2)
    criar_venda(queijo, 2, dias_atras=3)

    rel = client.get("/relatorios/desempenho").get_json()
    assert [i["produto_nome"] for i in rel["mais_vendidos"]] == ["Leite", "Queijo", "Parado"]
    assert [i["produto_nome"] for i in rel["menos_vendidos"]] == ["Parado", "Queijo", "Leite"]
    assert rel["mais_vendidos"][0]["faturamento"] == 30.0
    assert [(m["produto_nome"], m["margem_percentual"]) for m in rel["margens"]] == [
        ("Queijo", 50.0),
        ("Leite", 40.0),
        ("Parado", 0),
    ]
    assert rel["margens"][2]["preco_custo"] is None


def test_relatorio_de_tendencias(client):
    subindo = criar_produto("Subindo")
    criar_venda(subindo, 10, dias_atras=5)
    criar_venda(subindo, 5, dias_atras=40)
    caindo = criar_produto("Caindo")
    criar_venda(caindo, 4, dias_atras=45)
    estavel = criar_produto("Estável")
    criar_venda(estavel, 6, dias_atras=5)
    criar_venda(estavel, 6, dias_atras=35)
    novo = criar_produto("Novo")
    criar_venda(novo, 3, dias_atras=1)
    criar_produto("Sem venda")

    lista = client.get("/relatorios/tendencias").get_json()
    assert [(t["produto_nome"], t["variacao_percentual"], t["tendencia"]) for t in lista] == [
        ("Subindo", 100.0, "subindo"),
        ("Novo", 100, "subindo"),
        ("Estável", 0.0, "estavel"),
        ("Caindo", -100.0, "caindo"),
    ]
    assert lista[0]["vendas_periodo_atual"] == 10
    assert lista[0]["vendas_periodo_anterior"] == 5


@pytest.mark.parametrize("rota", ["consumo", "desempenho", "tendencias"])
def test_relatorio_dias_invalido(client, rota):
    r = client.get(f"/relatorios/{rota}?dias=0")
    assert r.status_code == 400
    assert r.get_json() == {"erro": "dias tem que ser entre 1 e 365"}
