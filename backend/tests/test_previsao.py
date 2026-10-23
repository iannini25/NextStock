import pytest

from tests.fabricas import criar_clima, criar_evento, criar_produto, criar_vendas_diarias


def previsoes(client, query=""):
    r = client.get("/previsao" + query)
    assert r.status_code == 200
    return {p["produto_nome"]: p for p in r.get_json()["previsoes"]}


def test_previsao_usa_media_por_dia_da_semana(client):
    p = criar_produto("Leite", quantidade_estoque=50)
    criar_vendas_diarias(p, 10)  # 10 por dia nos ultimos 28 dias

    leite = previsoes(client)["Leite"]
    assert leite["previsao_demanda"] == 70
    assert leite["media_diaria"] == 9.33  # 280 vendidos / 30 dias
    assert leite["fator_clima"] == 1.0
    assert leite["dias_com_evento"] == 0
    assert leite["estoque_atual"] == 50
    assert leite["unidade"] == "UN"


def test_previsao_sem_historico_e_zero(client):
    criar_produto("Novo")
    assert previsoes(client)["Novo"]["previsao_demanda"] == 0


def test_evento_aumenta_a_demanda(client):
    p = criar_produto("Leite")
    criar_vendas_diarias(p, 10)
    criar_evento(inicio=1, fim=2, impacto=50)

    leite = previsoes(client)["Leite"]
    assert leite["previsao_demanda"] == 80  # 2 dias com +50% (15 + 15) e 5 dias normais (50)
    assert leite["dias_com_evento"] == 2


@pytest.mark.parametrize("query, erro", [
    ("?dias=0", "dias tem que ser entre 1 e 365"),
    ("?dias=366", "dias tem que ser entre 1 e 365"),
    ("?clima=neve", "clima tem que ser auto, normal, calor, frio ou chuva"),
])
def test_parametros_invalidos(client, query, erro):
    r = client.get("/previsao" + query)
    assert r.status_code == 400
    assert r.get_json() == {"erro": erro}
