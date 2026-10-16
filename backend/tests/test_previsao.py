import pytest

from tests.fabricas import criar_clima, criar_evento, criar_produto, criar_vendas_diarias


def previsoes(client, query=""):
    r = client.get("/previsao" + query)
    assert r.status_code == 200
    return {p["produto_nome"]: p for p in r.get_json()["previsoes"]}


def test_estrutura_sem_clima_salvo(client):
    r = client.get("/previsao")
    assert r.status_code == 200
    corpo = r.get_json()
    assert set(corpo) == {"cidade", "fonte", "aviso", "clima", "clima_dias", "previsoes"}
    assert corpo["fonte"] == "nenhum"
    assert corpo["clima"] == "auto"
    assert corpo["clima_dias"] == []
    assert corpo["aviso"]


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


def test_clima_manual(client):
    p = criar_produto("Leite")
    criar_vendas_diarias(p, 10)
    leite = previsoes(client, "?clima=chuva_forte")["Leite"]
    assert leite["previsao_demanda"] == 53  # 70 * 0.75 = 52.5, arredonda pra cima
    assert leite["fator_clima"] == 0.75


def test_clima_automatico_usa_clima_salvo(client):
    p = criar_produto("Leite")
    criar_vendas_diarias(p, 10)
    for d in range(1, 8):
        criar_clima(d, "chuva_forte", chuva_mm=15.0)

    r = client.get("/previsao")
    corpo = r.get_json()
    assert corpo["fonte"] == "open-meteo"
    assert len(corpo["clima_dias"]) == 7
    assert corpo["previsoes"][0]["previsao_demanda"] == 53


def test_evento_aumenta_a_demanda(client):
    p = criar_produto("Leite")
    criar_vendas_diarias(p, 10)
    criar_evento(inicio=1, fim=2, impacto=50)

    leite = previsoes(client)["Leite"]
    assert leite["previsao_demanda"] == 80  # 2 dias com +50% (15 + 15) e 5 dias normais (50)
    assert leite["dias_com_evento"] == 2


def test_ordena_pela_maior_demanda(client):
    pouco = criar_produto("Pouco")
    criar_vendas_diarias(pouco, 1)
    muito = criar_produto("Muito")
    criar_vendas_diarias(muito, 10)
    nomes = [p["produto_nome"] for p in client.get("/previsao").get_json()["previsoes"]]
    assert nomes == ["Muito", "Pouco"]


@pytest.mark.parametrize("query, erro", [
    ("?dias=0", "dias tem que ser entre 1 e 365"),
    ("?dias=366", "dias tem que ser entre 1 e 365"),
    ("?clima=neve", "clima tem que ser auto, normal, calor, frio ou chuva"),
])
def test_parametros_invalidos(client, query, erro):
    r = client.get("/previsao" + query)
    assert r.status_code == 400
    assert r.get_json() == {"erro": erro}
