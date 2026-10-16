import pytest

from tests.fabricas import criar_categoria, criar_produto, dia


def nomes(client, query):
    r = client.get("/produtos" + query)
    assert r.status_code == 200, r.get_json()
    return [p["nome"] for p in r.get_json()]


@pytest.fixture
def loja():
    lat = criar_categoria("Laticínios")
    hort = criar_categoria("Hortifruti")
    criar_produto("Leite Integral", codigo_barras="7891000001", id_categoria=lat.id_categoria,
                  quantidade_estoque=50, estoque_minimo=10, data_validade=dia(20))
    criar_produto("Leite Desnatado", codigo_barras="7891000002", id_categoria=lat.id_categoria,
                  quantidade_estoque=5, estoque_minimo=10, data_validade=dia(3))
    criar_produto("Iogurte", codigo_barras="7891000003", id_categoria=lat.id_categoria,
                  quantidade_estoque=0, estoque_minimo=0, data_validade=dia(-2))
    criar_produto("Banana", codigo_barras="7892000001", id_categoria=hort.id_categoria,
                  quantidade_estoque=30, estoque_minimo=0)
    criar_produto("Alface", codigo_barras="7892000002", id_categoria=hort.id_categoria,
                  quantidade_estoque=2, estoque_minimo=15, data_validade=dia(0))
    return {"laticinios": lat.id_categoria, "hortifruti": hort.id_categoria}


def test_sem_filtro_devolve_tudo_como_antes(client, loja):
    # mesma lista e mesma ordem (cadastro) de antes dos filtros
    assert nomes(client, "") == ["Leite Integral", "Leite Desnatado", "Iogurte", "Banana", "Alface"]


def test_filtro_vazio_e_o_mesmo_que_sem_filtro(client, loja):
    assert nomes(client, "?busca=&id_categoria=&situacao=") == nomes(client, "")


def test_busca_por_parte_do_nome_sem_diferenciar_maiusculas(client, loja):
    assert nomes(client, "?busca=LEITE") == ["Leite Desnatado", "Leite Integral"]  # com filtro, ordem alfabetica
    assert nomes(client, "?busca=nana") == ["Banana"]


def test_busca_por_codigo_de_barras(client, loja):
    assert nomes(client, "?busca=7892000002") == ["Alface"]
    assert nomes(client, "?busca=7891") == ["Iogurte", "Leite Desnatado", "Leite Integral"]


def test_busca_com_espacos_nas_pontas(client, loja):
    assert nomes(client, "?busca=%20%20banana%20") == ["Banana"]


def test_porcentagem_e_sublinhado_sao_texto_comum(client, loja):
    criar_produto("Desconto 50% off")
    criar_produto("Leite_Especial")
    assert nomes(client, "?busca=50%25") == ["Desconto 50% off"]
    assert nomes(client, "?busca=e_e") == ["Leite_Especial"]


def test_filtro_por_categoria(client, loja):
    assert nomes(client, f"?id_categoria={loja['hortifruti']}") == ["Alface", "Banana"]


@pytest.mark.parametrize("situacao, esperado", [
    ("baixo_estoque", ["Alface", "Leite Desnatado"]),
    ("sem_estoque", ["Iogurte"]),
    ("vencendo", ["Alface", "Leite Desnatado"]),  # vence hoje e em 3 dias
    ("vencido", ["Iogurte"]),
    ("VENCIDO", ["Iogurte"]),
])
def test_filtro_por_situacao(client, loja, situacao, esperado):
    assert nomes(client, f"?situacao={situacao}") == esperado


def test_filtros_combinados(client, loja):
    assert nomes(client, f"?busca=leite&situacao=baixo_estoque") == ["Leite Desnatado"]
    assert nomes(client, f"?id_categoria={loja['laticinios']}&situacao=vencendo") == ["Leite Desnatado"]
    assert nomes(client, f"?busca=banana&id_categoria={loja['laticinios']}") == []


def test_baixo_estoque_bate_com_o_risco_de_ruptura_por_minimo(client, loja):
    no_minimo = {p["nome"] for p in client.get("/produtos/risco-ruptura").get_json() if p["motivo"].startswith("estoque no mínimo")}
    assert set(nomes(client, "?situacao=baixo_estoque")) == no_minimo


def test_resposta_tem_os_mesmos_campos_de_antes(client, loja):
    sem = client.get("/produtos").get_json()
    com = client.get("/produtos?busca=banana").get_json()
    assert set(com[0]) == set(sem[0])


@pytest.mark.parametrize("query, erro", [
    ("?id_categoria=abc", "id_categoria tem que ser número"),
    ("?situacao=acabando", "situação inválida. use: baixo_estoque, sem_estoque, vencendo, vencido"),
    ("?busca=" + "x" * 101, "busca pode ter no máximo 100 caracteres"),
])
def test_filtro_invalido(client, query, erro):
    r = client.get("/produtos" + query)
    assert r.status_code == 400
    assert r.get_json() == {"erro": erro}


def test_usuario_comum_tambem_filtra(client_usuario, loja):
    assert nomes(client_usuario, "?busca=banana") == ["Banana"]
