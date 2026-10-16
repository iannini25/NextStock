import pytest

from tests.fabricas import criar_produto, criar_venda, criar_vendas_diarias, dia


def entrada(client, produto, quantidade, **extra):
    r = client.post("/lotes", json={"id_produto": produto.id_produto, "quantidade": quantidade, **extra})
    assert r.status_code == 201, r.get_json()
    return r.get_json()["lote"]


def excesso(client, **params):
    r = client.get("/alertas/excesso", query_string=params)
    assert r.status_code == 200, r.get_json()
    return r.get_json()


def do_produto(alertas, nome, tipo):
    return [a for a in alertas if a["produto_nome"] == nome and a["tipo"] == tipo]


def produto_vendendo(nome, por_dia, **campos):
    # vendas diarias nos ultimos 28 dias -> previsao de `por_dia` por dia
    p = criar_produto(nome, **campos)
    criar_vendas_diarias(p, por_dia)
    return p


# ---------- excesso perecivel ----------

def test_lote_que_vence_antes_de_vender_tudo(client):
    iogurte = produto_vendendo("Iogurte", 1, preco_custo=2)
    lote = entrada(client, iogurte, 10, data_validade=dia(4).isoformat())
    [alerta] = do_produto(excesso(client), "Iogurte", "perecivel")
    # vende 1 por dia: hoje + 4 dias = 5 unidades antes de vencer; sobram 5
    assert alerta["quantidade_em_risco"] == 5
    assert alerta["valor_em_risco"] == 10.0
    assert alerta["id_lote"] == lote["id_lote"]
    assert alerta["dias_para_vencer"] == 4
    assert alerta["demanda_diaria"] == 1.0
    assert "5 de 10 UN não devem ser vendidos antes de vencer (em 4 dia(s))" in alerta["mensagem"]


def test_lote_que_da_tempo_de_vender_nao_gera_alerta(client):
    leite = produto_vendendo("Leite", 5)
    entrada(client, leite, 20, data_validade=dia(10).isoformat())
    assert do_produto(excesso(client), "Leite", "perecivel") == []


def test_fila_de_lotes_o_segundo_so_comeca_quando_o_primeiro_acaba(client):
    queijo = produto_vendendo("Queijo", 1, preco_custo=1)
    entrada(client, queijo, 3, data_validade=dia(10).isoformat(), codigo_lote="DEPOIS")
    entrada(client, queijo, 10, data_validade=dia(6).isoformat(), codigo_lote="ANTES")
    alertas = do_produto(excesso(client), "Queijo", "perecivel")
    # ANTES (vence em 6): vende 7 e sobram 3. DEPOIS comeca no dia 7 e tem 4 dias: vende os 3. so ANTES tem risco
    assert [(a["lote"], a["quantidade_em_risco"]) for a in alertas] == [("Lote ANTES", 3)]


def test_produto_sem_venda_com_validade_tem_tudo_em_risco(client):
    parado = criar_produto("Parado", preco_custo=4)
    entrada(client, parado, 6, data_validade=dia(20).isoformat())
    [alerta] = do_produto(excesso(client), "Parado", "perecivel")
    assert (alerta["quantidade_em_risco"], alerta["valor_em_risco"]) == (6, 24.0)


def test_lote_sem_validade_e_lote_vencido_nao_entram_no_perecivel(client):
    arroz = criar_produto("Arroz", quantidade_estoque=50)  # sem validade
    entrada(client, arroz, 4, data_validade=dia(-2).isoformat())  # vencido: e alerta de vencimento, nao de excesso
    assert do_produto(excesso(client), "Arroz", "perecivel") == []


# ---------- excesso de cobertura ----------

def test_estoque_que_cobre_muitos_dias(client):
    feijao = produto_vendendo("Feijão", 1, quantidade_estoque=100, preco_custo=3)
    [alerta] = do_produto(excesso(client), "Feijão", "cobertura")
    assert alerta["dias_cobertura"] == 100
    assert alerta["quantidade_em_risco"] == 70  # o que passa dos 30 dias
    assert alerta["valor_em_risco"] == 210.0
    assert "cobre 100 dias de venda (o ideal é até 30)" in alerta["mensagem"]


def test_cobertura_dentro_do_limite_nao_alerta(client):
    produto_vendendo("Feijão", 1, quantidade_estoque=20)
    assert do_produto(excesso(client), "Feijão", "cobertura") == []


def test_limite_de_cobertura_configuravel(client):
    produto_vendendo("Feijão", 1, quantidade_estoque=20)
    assert len(do_produto(excesso(client, dias_cobertura=10), "Feijão", "cobertura")) == 1


def test_sem_venda_prevista_e_cobertura_infinita(client):
    criar_produto("Enfeite", quantidade_estoque=7)
    [alerta] = do_produto(excesso(client), "Enfeite", "cobertura")
    assert alerta["dias_cobertura"] is None
    assert alerta["mensagem"] == "Sem venda prevista: 7 UN parados no estoque."
    assert alerta["prioridade"] == "media"


def test_sem_estoque_nao_tem_excesso(client):
    criar_produto("Vazio")
    assert do_produto(excesso(client), "Vazio", "cobertura") == []


def test_produto_no_minimo_nao_e_excesso_de_cobertura(client):
    # vende pouco (cobre muitos dias), mas esta no minimo: e "Vai faltar", nao excesso
    pouco = criar_produto("Pouco", quantidade_estoque=7, estoque_minimo=10)
    criar_venda(pouco, 5, dias_atras=1)
    assert do_produto(excesso(client), "Pouco", "cobertura") == []
    assert "Pouco" in [p["nome"] for p in client.get("/produtos/risco-ruptura").get_json()]


# ---------- prioridade ----------

def test_prioridade_pelo_prazo(client):
    perto = criar_produto("Perto", preco_custo=1)
    entrada(client, perto, 5, data_validade=dia(2).isoformat())
    meio = criar_produto("Meio", preco_custo=1)
    entrada(client, meio, 5, data_validade=dia(6).isoformat())
    longe = criar_produto("Longe", preco_custo=1)
    entrada(client, longe, 5, data_validade=dia(20).isoformat())
    alertas = excesso(client)
    prioridade = {a["produto_nome"]: a["prioridade"] for a in alertas if a["tipo"] == "perecivel"}
    assert prioridade == {"Perto": "alta", "Meio": "media", "Longe": "baixa"}


def test_valor_alto_sobe_a_prioridade(client):
    caro = criar_produto("Caro", preco_custo=50)
    entrada(client, caro, 5, data_validade=dia(20).isoformat())  # R$ 250 em risco
    [alerta] = do_produto(excesso(client), "Caro", "perecivel")
    assert alerta["prioridade"] == "media"  # baixa pelo prazo, sobe pelo valor


def test_classe_a_sobe_a_prioridade(client):
    estrela = produto_vendendo("Estrela", 10, preco_custo=1)  # quase todo o faturamento: classe A
    outro = criar_produto("Outro")
    criar_venda(outro, 1, dias_atras=2)
    entrada(client, estrela, 300, data_validade=dia(20).isoformat())
    [alerta] = do_produto(excesso(client), "Estrela", "perecivel")
    # vende 10/dia por 21 dias = 210; sobram 90 (R$ 90, nao chega no valor alto)
    assert (alerta["quantidade_em_risco"], alerta["valor_em_risco"]) == (90, 90.0)
    assert alerta["classe_abc"] == "A"
    assert alerta["prioridade"] == "media"  # baixa pelo prazo, sobe um nivel por ser classe A

    # mesmo prazo e mesmo valor (90 x R$ 1), mas nao e classe A
    outro_lote = entrada(client, outro, 90, data_validade=dia(20).isoformat(), custo_unitario=1)
    [alerta_c] = [a for a in do_produto(excesso(client), "Outro", "perecivel") if a["id_lote"] == outro_lote["id_lote"]]
    assert alerta_c["classe_abc"] != "A"
    assert alerta_c["prioridade"] == "baixa"


def test_ordem_alta_primeiro(client):
    longe = criar_produto("Longe", preco_custo=1)
    entrada(client, longe, 5, data_validade=dia(20).isoformat())
    perto = criar_produto("Perto", preco_custo=1)
    entrada(client, perto, 5, data_validade=dia(1).isoformat())
    prioridades = [a["prioridade"] for a in excesso(client)]
    assert prioridades == sorted(prioridades, key=lambda p: {"alta": 0, "media": 1, "baixa": 2}[p])


def test_dias_cobertura_invalido(client):
    r = client.get("/alertas/excesso?dias_cobertura=0")
    assert r.status_code == 400
    assert r.get_json() == {"erro": "dias_cobertura tem que ser entre 1 e 365"}


# ---------- falta (Vai faltar) ganha prioridade ----------

def test_risco_de_ruptura_ganha_classe_e_prioridade_sem_mudar_o_resto(client):
    estrela = produto_vendendo("Estrela", 10, quantidade_estoque=5, estoque_minimo=10)  # classe A
    pouco = criar_produto("Pouco", quantidade_estoque=2, estoque_minimo=5)
    criar_venda(pouco, 1, dias_atras=3)
    zerado = criar_produto("Zerado", quantidade_estoque=0, estoque_minimo=5)
    criar_venda(zerado, 1, dias_atras=3)

    itens = {p["nome"]: p for p in client.get("/produtos/risco-ruptura").get_json()}
    assert (itens["Estrela"]["classe_abc"], itens["Estrela"]["prioridade"]) == ("A", "alta")
    assert itens["Pouco"]["prioridade"] in ("media", "baixa")
    assert itens["Zerado"]["prioridade"] == "alta"  # zerado e sempre alta
    assert itens["Estrela"]["motivo"].startswith("estoque no mínimo")  # campos antigos continuam
    assert itens["Estrela"]["quantidade_estoque"] == 5


# ---------- resumo pro selo ----------

def test_resumo_bate_com_as_listas(client):
    criar_produto("Vence", quantidade_estoque=3, data_validade=dia(2))
    criar_produto("Falta", quantidade_estoque=1, estoque_minimo=5)
    parado = criar_produto("Parado", preco_custo=1)
    entrada(client, parado, 4, data_validade=dia(20).isoformat())

    resumo = client.get("/alertas/resumo").get_json()
    assert resumo["vencendo"] == len(client.get("/produtos/vencendo?dias=7").get_json())
    assert resumo["falta"] == len(client.get("/produtos/risco-ruptura").get_json())
    assert resumo["excesso"] == len(excesso(client))
    assert resumo["total"] == resumo["vencendo"] + resumo["falta"] + resumo["excesso"]
    assert resumo["total"] > 0


def test_resumo_vazio(client):
    assert client.get("/alertas/resumo").get_json() == {
        "vencendo": 0, "falta": 0, "excesso": 0, "temperatura": 0, "total": 0, "prioridade_alta": 0,
    }


def test_usuario_comum_ve_os_alertas(client_usuario):
    assert client_usuario.get("/alertas/excesso").status_code == 200
    assert client_usuario.get("/alertas/resumo").status_code == 200


@pytest.mark.parametrize("rota", ["/alertas/excesso", "/alertas/resumo"])
def test_alertas_exigem_login(client_anonimo, admin, rota):
    assert client_anonimo.get(rota).status_code == 401
