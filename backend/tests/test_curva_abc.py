import pytest

from services.classificar_curva_abc_service import ClassificarCurvaAbcService
from tests.fabricas import criar_categoria, criar_produto, criar_venda


def curva(client, **params):
    r = client.get("/relatorios/curva-abc", query_string=params)
    assert r.status_code == 200, r.get_json()
    return r.get_json()


def classes(corpo):
    return [(i["produto_nome"], i["classe"]) for i in corpo["itens"]]


@pytest.fixture
def loja():
    # faturamento em 30 dias (preco 1 pra facilitar a conta): total 1000
    for nome, vendido in [("Arroz", 500), ("Feijão", 250), ("Café", 100), ("Açúcar", 80), ("Sal", 50), ("Óleo", 20)]:
        p = criar_produto(nome, preco_venda=1)
        criar_venda(p, vendido, dias_atras=3)
    criar_produto("Parado", preco_venda=10)


def test_classes_pelos_cortes_de_80_e_95(client, loja):
    corpo = curva(client)
    # acumulado antes de cada um: 0, 50, 75, 85, 93, 98, 100
    assert classes(corpo) == [
        ("Arroz", "A"), ("Feijão", "A"), ("Café", "A"),  # comecam antes de 80%
        ("Açúcar", "B"), ("Sal", "B"),  # comecam entre 80% e 95%
        ("Óleo", "C"),  # comeca depois de 95%
        ("Parado", "C"),  # sem venda
    ]
    arroz = corpo["itens"][0]
    assert (arroz["posicao"], arroz["valor"], arroz["percentual"], arroz["percentual_acumulado"]) == (1, 500.0, 50.0, 50.0)
    assert corpo["itens"][2]["percentual_acumulado"] == 85.0
    assert (corpo["total"], corpo["criterio"], corpo["dias"]) == (1000.0, "faturamento", 30)
    assert corpo["limites"] == {"A": 80, "B": 95}


def test_resumo_por_classe(client, loja):
    resumo = curva(client)["resumo"]
    assert resumo["A"] == {"produtos": 3, "valor": 850.0, "percentual_valor": 85.0}
    assert resumo["B"] == {"produtos": 2, "valor": 130.0, "percentual_valor": 13.0}
    assert resumo["C"] == {"produtos": 2, "valor": 20.0, "percentual_valor": 2.0}


def test_criterio_quantidade(client):
    caro = criar_produto("Caro", preco_venda=100)
    criar_venda(caro, 1, dias_atras=1)  # 100 de faturamento, 1 unidade
    barato = criar_produto("Barato", preco_venda=1)
    criar_venda(barato, 10, dias_atras=1)  # 10 de faturamento, 10 unidades
    # faturamento: Caro tem 90,9% -> Barato comeca depois de 80% -> B
    assert classes(curva(client)) == [("Caro", "A"), ("Barato", "B")]
    # quantidade: Barato tem 90,9% das unidades -> agora o Caro e que fica em B
    por_quantidade = curva(client, criterio="quantidade")
    assert classes(por_quantidade) == [("Barato", "A"), ("Caro", "B")]
    assert por_quantidade["itens"][0]["valor"] == 10
    assert por_quantidade["itens"][0]["faturamento"] == 10.0


@pytest.mark.parametrize("params, erro", [
    ({"dias": 0}, "dias tem que ser entre 1 e 365"),
    ({"dias": 400}, "dias tem que ser entre 1 e 365"),
    ({"criterio": "lucro"}, "criterio tem que ser faturamento ou quantidade"),
])
def test_parametros_invalidos(client, params, erro):
    r = client.get("/relatorios/curva-abc", query_string=params)
    assert r.status_code == 400
    assert r.get_json() == {"erro": erro}
