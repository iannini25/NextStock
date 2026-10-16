from tests.fabricas import criar_produto, criar_vendas_diarias, dia


def montar_validades():
    criar_produto("Vencido", data_validade=dia(-3))
    criar_produto("Vence hoje", data_validade=dia(0))
    criar_produto("Vence em 2 dias", data_validade=dia(2))
    criar_produto("Vence em 30 dias", data_validade=dia(30))
    criar_produto("Sem validade")


def test_vencendo_padrao_7_dias_inclui_vencidos_em_ordem(client):
    montar_validades()
    r = client.get("/produtos/vencendo")
    assert r.status_code == 200
    assert [p["nome"] for p in r.get_json()] == ["Vencido", "Vence hoje", "Vence em 2 dias"]


def test_vencendo_com_dias(client):
    montar_validades()
    r = client.get("/produtos/vencendo?dias=30")
    assert [p["nome"] for p in r.get_json()] == ["Vencido", "Vence hoje", "Vence em 2 dias", "Vence em 30 dias"]


def test_vencendo_parametro_invalido_usa_7(client):
    montar_validades()
    r = client.get("/produtos/vencendo?dias=abc")
    assert r.status_code == 200
    assert len(r.get_json()) == 3


def test_vencendo_fora_do_intervalo(client):
    r = client.get("/produtos/vencendo?dias=400")
    assert r.status_code == 400
    assert r.get_json() == {"erro": "dias tem que ser entre 0 e 365"}


def test_risco_de_ruptura_por_minimo_e_por_previsao(client):
    criar_produto("No mínimo", quantidade_estoque=5, estoque_minimo=10)
    criar_produto("Folgado", quantidade_estoque=100, estoque_minimo=10)
    criar_produto("Sem mínimo e sem venda", quantidade_estoque=0, estoque_minimo=0)
    demanda = criar_produto("Demanda alta", quantidade_estoque=5, estoque_minimo=0)
    criar_vendas_diarias(demanda, 10)
    ambos = criar_produto("Mínimo e demanda", quantidade_estoque=3, estoque_minimo=10)
    criar_vendas_diarias(ambos, 10)

    r = client.get("/produtos/risco-ruptura")
    assert r.status_code == 200
    motivos = {p["nome"]: p["motivo"] for p in r.get_json()}
    assert motivos == {
        "No mínimo": "estoque no mínimo",
        "Demanda alta": "demanda prevista (70) maior que o estoque (5) nos próximos 7 dias",
        "Mínimo e demanda": "estoque no mínimo e demanda prevista (70) maior que o estoque (3) nos próximos 7 dias",
    }
