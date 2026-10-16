from tests.fabricas import criar_produto, criar_vendas_diarias, dia


def test_recomendacoes_por_tipo_e_prioridade(client):
    criar_produto("Vencido", quantidade_estoque=5, data_validade=dia(-1))
    criar_produto("Vence logo", quantidade_estoque=5, data_validade=dia(2))
    criar_produto("No mínimo", quantidade_estoque=2, estoque_minimo=5)
    excesso = criar_produto("Excesso", quantidade_estoque=1000)
    criar_vendas_diarias(excesso, 1, de=1, ate=30)
    demanda = criar_produto("Demanda alta", quantidade_estoque=5)
    criar_vendas_diarias(demanda, 10)

    r = client.get("/recomendacoes")
    assert r.status_code == 200
    lista = r.get_json()

    assert {(i["produto_nome"], i["tipo"], i["prioridade"]) for i in lista} == {
        ("Vencido", "retirar", "alta"),
        ("Vencido", "produto_parado", "media"),
        ("Vence logo", "promocao", "alta"),
        ("Vence logo", "produto_parado", "media"),
        ("No mínimo", "repor", "alta"),
        ("No mínimo", "produto_parado", "media"),
        ("Excesso", "comprar_menos", "media"),
        ("Demanda alta", "repor", "alta"),
    }

    mensagens = {(i["produto_nome"], i["tipo"]): i["mensagem"] for i in lista}
    assert mensagens[("Vencido", "retirar")] == "Vencido com 5 em estoque: tire da prateleira"
    assert mensagens[("Vence logo", "promocao")] == "Vence em 2 dia(s) com 5 em estoque: faça promoção"
    assert mensagens[("No mínimo", "repor")] == "Estoque (2) no mínimo (5): repor agora"
    assert mensagens[("Excesso", "comprar_menos")] == "Estoque cobre 1000 dias de venda: compre menos"
    assert mensagens[("Demanda alta", "repor")] == (
        "Clima dos próximos 7 dias: demanda prevista 70 acima do estoque 5"
    )

    # prioridade alta sempre antes da media
    prioridades = [i["prioridade"] for i in lista]
    assert prioridades == sorted(prioridades, key=lambda p: {"alta": 0, "media": 1}[p])
