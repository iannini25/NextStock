import pytest

from tests.fabricas import criar_evento


def test_cria_evento(client):
    r = client.post("/eventos", json={
        "nome": "Festa junina",
        "data_inicio": "2026-06-20",
        "data_fim": "2026-06-22",
        "impacto_percentual": 30,
    })
    assert r.status_code == 201
    ev = r.get_json()
    assert ev["nome"] == "Festa junina"
    assert ev["data_inicio"] == "2026-06-20"
    assert ev["data_fim"] == "2026-06-22"
    assert ev["impacto_percentual"] == 30


def test_impacto_e_opcional(client):
    r = client.post("/eventos", json={"nome": "Feira", "data_inicio": "2026-06-20", "data_fim": "2026-06-20"})
    assert r.status_code == 201
    assert r.get_json()["impacto_percentual"] == 0


@pytest.mark.parametrize("dados, erro", [
    ({"data_inicio": "2026-06-20", "data_fim": "2026-06-22"}, "nome é obrigatório"),
    ({"nome": "X", "data_inicio": "2026-06-20"}, "data inicio e data fim são obrigatórias"),
    ({"nome": "X", "data_inicio": "2026-06-22", "data_fim": "2026-06-20"}, "data fim tem que ser depois da data inicio"),
    ({"nome": "X", "data_inicio": "2026-06-20", "data_fim": "2026-06-22", "impacto_percentual": "abc"},
     "impacto tem que ser numero inteiro"),
    ({"nome": "X", "data_inicio": "20/06/2026", "data_fim": "2026-06-22"}, "data tem que ser aaaa-mm-dd"),
])
def test_evento_invalido(client, dados, erro):
    r = client.post("/eventos", json=dados)
    assert r.status_code == 400
    assert r.get_json() == {"erro": erro}


def test_lista_em_ordem_de_inicio(client):
    criar_evento("Depois", inicio=10, fim=11)
    criar_evento("Antes", inicio=-5, fim=-4)
    nomes = [e["nome"] for e in client.get("/eventos").get_json()]
    assert nomes == ["Antes", "Depois"]


def test_exclui_evento(client):
    ev = criar_evento()
    assert client.delete(f"/eventos/{ev.id_evento}").status_code == 204
    assert client.get("/eventos").get_json() == []


def test_exclui_evento_inexistente(client):
    r = client.delete("/eventos/999")
    assert r.status_code == 404
    assert r.get_json() == {"erro": "evento não encontrado"}
