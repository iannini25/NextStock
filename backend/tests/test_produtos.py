import pytest

from tests.fabricas import criar_categoria, criar_produto, criar_venda


def test_cria_produto_completo(client):
    cat = criar_categoria("Laticínios")
    r = client.post("/produtos", json={
        "nome": "Iogurte Natural 170g",
        "id_categoria": cat.id_categoria,
        "codigo_barras": "7891234567890",
        "preco_custo": "1.80",
        "preco_venda": "3.50",
        "quantidade_estoque": 60,
        "estoque_minimo": 20,
        "unidade": "un",
        "data_validade": "2026-08-15",
    })
    assert r.status_code == 201
    p = r.get_json()
    assert isinstance(p["id_produto"], int)
    assert p["nome"] == "Iogurte Natural 170g"
    assert p["id_categoria"] == cat.id_categoria
    assert p["categoria_nome"] == "Laticínios"
    assert p["codigo_barras"] == "7891234567890"
    assert p["preco_custo"] == 1.8
    assert p["preco_venda"] == 3.5
    assert p["quantidade_estoque"] == 60
    assert p["estoque_minimo"] == 20
    assert p["unidade"] == "UN"
    assert p["data_validade"] == "2026-08-15"


def test_cria_produto_so_com_obrigatorios(client):
    r = client.post("/produtos", json={"nome": "Pão", "preco_venda": 2})
    assert r.status_code == 201
    p = r.get_json()
    assert p["quantidade_estoque"] == 0
    assert p["estoque_minimo"] == 0
    assert p["unidade"] == "UN"
    assert p["codigo_barras"] is None
    assert p["id_categoria"] is None
    assert p["categoria_nome"] is None
    assert p["preco_custo"] is None
    assert p["data_validade"] is None


@pytest.mark.parametrize("dados, erro", [
    ({"preco_venda": 2}, "nome é obrigatório"),
    ({"nome": "X"}, "preço de venda é obrigatório"),
    ({"nome": "X", "preco_venda": "-1"}, "valor nao pode ser negativo"),
    ({"nome": "X", "preco_venda": "abc"}, "valor precisa ser numero"),
    ({"nome": "X", "preco_venda": 2, "quantidade_estoque": "1.5"}, "valor precisa ser numero inteiro"),
    ({"nome": "X", "preco_venda": 2, "data_validade": "15/08/2026"}, "data tem que ser aaaa-mm-dd"),
    ({"nome": "X", "preco_venda": 2, "id_categoria": 999}, "categoria não existe"),
])
def test_cria_produto_invalido(client, dados, erro):
    r = client.post("/produtos", json=dados)
    assert r.status_code == 400
    assert r.get_json() == {"erro": erro}


def test_nao_cria_codigo_de_barras_repetido(client):
    criar_produto("Leite", codigo_barras="789")
    r = client.post("/produtos", json={"nome": "Outro", "preco_venda": 2, "codigo_barras": "789"})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "já existe produto com esse código de barras"}


def test_lista_produtos(client):
    cat = criar_categoria("Hortifruti")
    criar_produto("Banana", id_categoria=cat.id_categoria)
    criar_produto("Leite")
    r = client.get("/produtos")
    assert r.status_code == 200
    nomes = {p["nome"]: p["categoria_nome"] for p in r.get_json()}
    assert nomes == {"Banana": "Hortifruti", "Leite": None}


def test_busca_por_id(client):
    p = criar_produto("Leite")
    r = client.get(f"/produtos/{p.id_produto}")
    assert r.status_code == 200
    assert r.get_json()["nome"] == "Leite"


def test_busca_inexistente(client):
    r = client.get("/produtos/999")
    assert r.status_code == 404
    assert r.get_json() == {"erro": "produto não encontrado"}


def test_atualiza_produto(client):
    p = criar_produto("Leite", codigo_barras="789", quantidade_estoque=5)
    r = client.put(f"/produtos/{p.id_produto}", json={
        "nome": "Leite Desnatado",
        "codigo_barras": "789",
        "preco_custo": 2.5,
        "preco_venda": 4.5,
        "quantidade_estoque": 30,
        "estoque_minimo": 10,
        "unidade": "cx",
        "data_validade": "2026-12-01",
    })
    assert r.status_code == 200
    atualizado = r.get_json()
    assert atualizado["nome"] == "Leite Desnatado"
    assert atualizado["preco_venda"] == 4.5
    assert atualizado["quantidade_estoque"] == 30
    assert atualizado["estoque_minimo"] == 10
    assert atualizado["unidade"] == "CX"
    assert atualizado["data_validade"] == "2026-12-01"


def test_atualiza_com_codigo_de_outro_produto(client):
    criar_produto("Leite", codigo_barras="111")
    outro = criar_produto("Iogurte", codigo_barras="222")
    r = client.put(f"/produtos/{outro.id_produto}", json={"nome": "Iogurte", "preco_venda": 3, "codigo_barras": "111"})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "já existe produto com esse código de barras"}


def test_atualiza_sem_nome(client):
    p = criar_produto("Leite")
    r = client.put(f"/produtos/{p.id_produto}", json={"preco_venda": 3})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "nome é obrigatório"}


def test_atualiza_inexistente(client):
    r = client.put("/produtos/999", json={"nome": "X", "preco_venda": 1})
    assert r.status_code == 404


def test_exclui_produto(client):
    p = criar_produto("Leite")
    r = client.delete(f"/produtos/{p.id_produto}")
    assert r.status_code == 204
    assert client.get(f"/produtos/{p.id_produto}").status_code == 404


def test_exclui_inexistente(client):
    assert client.delete("/produtos/999").status_code == 404


def test_nao_exclui_produto_com_venda(client):
    p = criar_produto("Leite", quantidade_estoque=10)
    criar_venda(p, 1)
    r = client.delete(f"/produtos/{p.id_produto}")
    assert r.status_code == 400
    assert r.get_json() == {"erro": "não dá para apagar: esse produto tem vendas registradas"}
