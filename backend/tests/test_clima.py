import pytest

from services.atualizar_clima_service import AtualizarClimaService
from tests.fabricas import criar_clima


def test_clima_sem_dados(client):
    r = client.get("/clima")
    assert r.status_code == 200
    corpo = r.get_json()
    assert set(corpo) == {"cidade", "fonte", "aviso", "dias"}
    assert corpo["fonte"] == "nenhum"
    assert corpo["dias"] == []
    assert corpo["aviso"]


def test_clima_lista_a_janela_de_30_dias_atras_ate_16_a_frente(client):
    criar_clima(-40, "normal")  # fora da janela
    criar_clima(-1, "chuva", temperatura=19.04, chuva_mm=5.26)
    criar_clima(3, "calor", temperatura=31.0)

    corpo = client.get("/clima").get_json()
    assert corpo["fonte"] == "open-meteo"
    assert corpo["aviso"] is None
    assert [d["condicao"] for d in corpo["dias"]] == ["chuva", "calor"]
    assert corpo["dias"][0]["temperatura"] == 19.0
    assert corpo["dias"][0]["chuva_mm"] == 5.3


@pytest.mark.parametrize("temperatura, chuva, esperado", [
    (25, 12, "chuva_forte"),
    (25, 10, "chuva_forte"),
    (25, 2, "chuva"),
    (30, 0, "calor"),
    (29, None, "calor"),
    (17, 0, "frio"),
    (22, 1.9, "normal"),
    (None, 0, "normal"),
])
def test_classificacao_do_dia(temperatura, chuva, esperado):
    assert AtualizarClimaService().classificar(temperatura, chuva) == esperado
