from tests.fabricas import criar_categoria, criar_produto


def test_cria_e_lista(client):
    r = client.post("/categorias", json={"nome": "Bebidas", "descricao": "Sucos e refrigerantes"})
    assert r.status_code == 201
    criada = r.get_json()
    assert criada["nome"] == "Bebidas"
    assert criada["descricao"] == "Sucos e refrigerantes"
    assert isinstance(criada["id_categoria"], int)
    assert client.get("/categorias").get_json() == [criada]


def test_nao_cria_categoria_com_nome_repetido(client):
    criar_categoria("Hortifruti")
    for nome in ["Hortifruti", "hortifruti", "  HORTIFRUTI  "]:
        r = client.post("/categorias", json={"nome": nome})
        assert r.status_code == 400
        assert r.get_json() == {"erro": "já existe categoria com esse nome"}
    assert len(client.get("/categorias").get_json()) == 1


def test_cria_sem_nome(client):
    r = client.post("/categorias", json={"descricao": "sem nome"})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "nome é obrigatório"}


def test_atualiza(client):
    c = criar_categoria("Padaria")
    r = client.put(f"/categorias/{c.id_categoria}", json={"nome": "Panificação", "descricao": "pães"})
    assert r.status_code == 200
    assert r.get_json()["nome"] == "Panificação"
    assert r.get_json()["descricao"] == "pães"


def test_exclui(client):
    c = criar_categoria("Padaria")
    r = client.delete(f"/categorias/{c.id_categoria}")
    assert r.status_code == 204
    assert client.get(f"/categorias/{c.id_categoria}").status_code == 404


def test_nao_exclui_categoria_com_produto(client):
    c = criar_categoria("Laticínios")
    criar_produto("Leite", id_categoria=c.id_categoria)
    r = client.delete(f"/categorias/{c.id_categoria}")
    assert r.status_code == 400
    assert r.get_json() == {"erro": "não dá para apagar: existem produtos nessa categoria"}
