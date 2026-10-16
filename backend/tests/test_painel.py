from tests.fabricas import criar_produto, criar_venda, dia

CHAVES = {
    "total_produtos",
    "itens_em_estoque",
    "valor_estoque",
    "produtos_vencidos",
    "valor_vencido",
    "produtos_vencendo",
    "produtos_em_risco",
    "vendas_30_dias",
    "faturamento_30_dias",
    "percentual_desperdicio",
    "giro_estoque",
}


def test_painel_vazio(client):
    r = client.get("/painel")
    assert r.status_code == 200
    painel = r.get_json()
    assert set(painel) == CHAVES
    assert all(v == 0 for v in painel.values())


def test_painel_calcula_indicadores(client):
    criar_produto("Vencido", quantidade_estoque=10, preco_custo=2, preco_venda=5, data_validade=dia(-1))
    em_risco = criar_produto("Em risco", quantidade_estoque=5, preco_custo=4, preco_venda=10, estoque_minimo=10)
    criar_produto("Vence em 3 dias", quantidade_estoque=1, preco_custo=1, preco_venda=2, data_validade=dia(3))
    criar_venda(em_risco, 3, dias_atras=5)
    criar_venda(em_risco, 99, dias_atras=40)  # fora dos 30 dias

    painel = client.get("/painel").get_json()
    assert set(painel) == CHAVES
    assert painel["total_produtos"] == 3
    assert painel["itens_em_estoque"] == 16
    assert painel["valor_estoque"] == 41.0
    assert painel["produtos_vencidos"] == 1
    assert painel["valor_vencido"] == 20.0
    assert painel["produtos_vencendo"] == 1  # vencendo em 7 dias, sem contar os vencidos
    assert painel["produtos_em_risco"] == 1
    assert painel["vendas_30_dias"] == 3
    assert painel["faturamento_30_dias"] == 30.0
    assert painel["percentual_desperdicio"] == 48.78  # 20 / 41
    assert painel["giro_estoque"] == 0.19  # 3 / 16
