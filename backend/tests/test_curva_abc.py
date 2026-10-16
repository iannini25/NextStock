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


def test_primeiro_colocado_e_sempre_a(client):
    dominante = criar_produto("Dominante", preco_venda=1)
    criar_venda(dominante, 900, dias_atras=1)
    pequeno = criar_produto("Pequeno", preco_venda=1)
    criar_venda(pequeno, 100, dias_atras=1)
    assert classes(curva(client)) == [("Dominante", "A"), ("Pequeno", "B")]  # 90% sozinho, mas comeca em 0%


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


def test_empate_fica_em_ordem_alfabetica(client):
    for nome in ("Banana", "Abacate"):
        criar_venda(criar_produto(nome, preco_venda=1), 10, dias_atras=1)
    assert [i["produto_nome"] for i in curva(client)["itens"]] == ["Abacate", "Banana"]


def test_periodo_sem_vendas_e_tudo_c(client):
    criar_produto("Leite")
    criar_produto("Pão")
    corpo = curva(client)
    assert {c for _, c in classes(corpo)} == {"C"}
    assert corpo["total"] == 0
    assert corpo["resumo"]["C"]["produtos"] == 2


def test_venda_fora_do_periodo_nao_conta(client):
    antigo = criar_produto("Antigo", preco_venda=1)
    criar_venda(antigo, 100, dias_atras=40)
    recente = criar_produto("Recente", preco_venda=1)
    criar_venda(recente, 5, dias_atras=2)
    assert classes(curva(client, dias=30)) == [("Recente", "A"), ("Antigo", "C")]
    assert classes(curva(client, dias=60))[0] == ("Antigo", "A")


def test_traz_categoria(client):
    cat = criar_categoria("Mercearia")
    criar_venda(criar_produto("Arroz", id_categoria=cat.id_categoria), 1, dias_atras=1)
    assert curva(client)["itens"][0]["categoria_nome"] == "Mercearia"


@pytest.mark.parametrize("params, erro", [
    ({"dias": 0}, "dias tem que ser entre 1 e 365"),
    ({"dias": 400}, "dias tem que ser entre 1 e 365"),
    ({"criterio": "lucro"}, "criterio tem que ser faturamento ou quantidade"),
])
def test_parametros_invalidos(client, params, erro):
    r = client.get("/relatorios/curva-abc", query_string=params)
    assert r.status_code == 400
    assert r.get_json() == {"erro": erro}


def test_usuario_comum_ve_a_curva(client_usuario, loja):
    assert client_usuario.get("/relatorios/curva-abc").status_code == 200


def test_classes_por_produto_para_outros_servicos(banco, loja):
    from models.produto_model import Produto

    mapa = ClassificarCurvaAbcService().classes(dias=30)
    nomes = {p.id_produto: p.nome for p in Produto.query.all()}
    assert {nomes[i]: c for i, c in mapa.items()}["Arroz"] == "A"
    assert {nomes[i]: c for i, c in mapa.items()}["Parado"] == "C"
