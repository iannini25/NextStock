from tests.fabricas import criar_produto, criar_vendas_diarias


def test_reposicao(client):
    baixa = criar_produto("Urgência baixa", quantidade_estoque=20, estoque_minimo=10)
    criar_vendas_diarias(baixa, 1, de=1, ate=30)  # media de 1 por dia
    criar_produto("Sem venda no mínimo", quantidade_estoque=2, estoque_minimo=5)
    criar_produto("Folgado sem venda", quantidade_estoque=100, estoque_minimo=5)
    longe = criar_produto("Longe do mínimo", quantidade_estoque=100, estoque_minimo=10)
    criar_vendas_diarias(longe, 1, de=1, ate=30)
    demanda = criar_produto("Demanda alta", quantidade_estoque=5, estoque_minimo=0)
    criar_vendas_diarias(demanda, 10)

    r = client.get("/reposicao")
    assert r.status_code == 200
    lista = r.get_json()
    por_nome = {item["produto_nome"]: item for item in lista}
    assert set(por_nome) == {"Urgência baixa", "Sem venda no mínimo", "Demanda alta"}

    assert por_nome["Urgência baixa"]["dias_ate_minimo"] == 10
    assert por_nome["Urgência baixa"]["prazo_ideal"] == "em 10 dia(s)"
    assert por_nome["Urgência baixa"]["urgencia"] == "baixa"
    assert por_nome["Urgência baixa"]["quantidade_ideal"] == 7
    assert por_nome["Urgência baixa"]["media_diaria"] == 1.0

    assert por_nome["Sem venda no mínimo"]["urgencia"] == "alta"
    assert por_nome["Sem venda no mínimo"]["prazo_ideal"] == "hoje"
    assert por_nome["Sem venda no mínimo"]["quantidade_ideal"] == 5
    assert por_nome["Sem venda no mínimo"]["media_diaria"] == 0

    assert por_nome["Demanda alta"]["urgencia"] == "alta"
    assert por_nome["Demanda alta"]["quantidade_ideal"] == 66  # 9,33 por dia x 7 dias

    # urgencia alta vem antes
    assert [item["urgencia"] for item in lista][-1] == "baixa"


def test_sugestao_de_compras(client):
    leite = criar_produto("Leite", quantidade_estoque=20, estoque_minimo=5, preco_custo=2)
    criar_vendas_diarias(leite, 10)
    sem_custo = criar_produto("Sem custo", quantidade_estoque=0, preco_custo=None)
    criar_vendas_diarias(sem_custo, 10)
    sobra = criar_produto("Sobrando", quantidade_estoque=500)
    criar_vendas_diarias(sobra, 10)

    r = client.get("/compras/sugestoes")
    assert r.status_code == 200
    lista = r.get_json()
    assert [s["produto_nome"] for s in lista] == ["Sem custo", "Leite"]  # maior quantidade primeiro

    leite_sugestao = lista[1]
    assert leite_sugestao["previsao_demanda"] == 70
    assert leite_sugestao["quantidade_sugerida"] == 55  # 70 + 5 de minimo - 20 em estoque
    assert leite_sugestao["preco_custo"] == 2.0
    assert leite_sugestao["custo_estimado"] == 110.0

    assert lista[0]["quantidade_sugerida"] == 70
    assert lista[0]["preco_custo"] is None
    assert lista[0]["custo_estimado"] == 0.0


def test_sugestao_de_compras_com_clima_manual(client):
    leite = criar_produto("Leite", quantidade_estoque=20, estoque_minimo=5)
    criar_vendas_diarias(leite, 10)
    lista = client.get("/compras/sugestoes?clima=chuva_forte").get_json()
    assert lista[0]["previsao_demanda"] == 53
    assert lista[0]["quantidade_sugerida"] == 38


def test_sugestao_de_compras_dias_invalido(client):
    r = client.get("/compras/sugestoes?dias=0")
    assert r.status_code == 400
    assert r.get_json() == {"erro": "dias tem que ser entre 1 e 365"}
