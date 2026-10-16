from tests.fabricas import criar_categoria, criar_produto


def test_lista_vazia(client):
    r = client.get("/categorias")
    assert r.status_code == 200
    assert r.get_json() == []


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


def test_cria_tirando_espacos_do_nome(client):
    r = client.post("/categorias", json={"nome": "  Bebidas  "})
    assert r.get_json()["nome"] == "Bebidas"


def test_nao_renomeia_para_nome_de_outra_categoria(client):
    criar_categoria("Hortifruti")
    padaria = criar_categoria("Padaria")
    r = client.put(f"/categorias/{padaria.id_categoria}", json={"nome": "HORTIFRUTI"})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "já existe categoria com esse nome"}


def test_edita_mantendo_o_proprio_nome(client):
    padaria = criar_categoria("Padaria")
    r = client.put(f"/categorias/{padaria.id_categoria}", json={"nome": "Padaria", "descricao": "pães"})
    assert r.status_code == 200
    assert r.get_json()["descricao"] == "pães"


def test_cria_sem_nome(client):
    r = client.post("/categorias", json={"descricao": "sem nome"})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "nome é obrigatório"}


def test_busca_por_id(client):
    c = criar_categoria("Padaria")
    r = client.get(f"/categorias/{c.id_categoria}")
    assert r.status_code == 200
    assert r.get_json()["nome"] == "Padaria"


def test_busca_inexistente(client):
    r = client.get("/categorias/999")
    assert r.status_code == 404
    assert r.get_json() == {"erro": "categoria não encontrada"}


def test_atualiza(client):
    c = criar_categoria("Padaria")
    r = client.put(f"/categorias/{c.id_categoria}", json={"nome": "Panificação", "descricao": "pães"})
    assert r.status_code == 200
    assert r.get_json()["nome"] == "Panificação"
    assert r.get_json()["descricao"] == "pães"


def test_atualiza_sem_nome(client):
    c = criar_categoria("Padaria")
    r = client.put(f"/categorias/{c.id_categoria}", json={"descricao": "x"})
    assert r.status_code == 400
    assert r.get_json() == {"erro": "nome é obrigatório"}


def test_atualiza_inexistente(client):
    r = client.put("/categorias/999", json={"nome": "X"})
    assert r.status_code == 404


def test_exclui(client):
    c = criar_categoria("Padaria")
    r = client.delete(f"/categorias/{c.id_categoria}")
    assert r.status_code == 204
    assert client.get(f"/categorias/{c.id_categoria}").status_code == 404


def test_exclui_inexistente(client):
    r = client.delete("/categorias/999")
    assert r.status_code == 404
    assert r.get_json() == {"erro": "categoria não encontrada"}


def test_nao_exclui_categoria_com_produto(client):
    c = criar_categoria("Laticínios")
    criar_produto("Leite", id_categoria=c.id_categoria)
    r = client.delete(f"/categorias/{c.id_categoria}")
    assert r.status_code == 400
    assert r.get_json() == {"erro": "não dá para apagar: existem produtos nessa categoria"}
