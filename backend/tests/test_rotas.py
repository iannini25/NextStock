import pytest

from app import app as flask_app

# todas as rotas que existem hoje. as etapas novas podem acrescentar rotas, mas nenhuma destas pode sumir.
ROTAS_EXISTENTES = {
    ("/", "GET"),
    ("/categorias", "GET"),
    ("/categorias", "POST"),
    ("/categorias/<int:id>", "GET"),
    ("/categorias/<int:id>", "PUT"),
    ("/categorias/<int:id>", "DELETE"),
    ("/produtos", "GET"),
    ("/produtos", "POST"),
    ("/produtos/<int:id>", "GET"),
    ("/produtos/<int:id>", "PUT"),
    ("/produtos/<int:id>", "DELETE"),
    ("/produtos/vencendo", "GET"),
    ("/produtos/risco-ruptura", "GET"),
    ("/vendas", "GET"),
    ("/vendas", "POST"),
    ("/eventos", "GET"),
    ("/eventos", "POST"),
    ("/eventos/<int:id>", "DELETE"),
    ("/previsao", "GET"),
    ("/clima", "GET"),
    ("/compras/sugestoes", "GET"),
    ("/reposicao", "GET"),
    ("/erp/importar", "POST"),
    ("/importar/modelo", "GET"),
    ("/importar", "POST"),
    ("/painel", "GET"),
    ("/recomendacoes", "GET"),
    ("/relatorios/consumo", "GET"),
    ("/relatorios/desempenho", "GET"),
    ("/relatorios/tendencias", "GET"),
    ("/assistente", "POST"),
    # etapa 1: empresa e usuarios
    ("/setup/status", "GET"),
    ("/setup", "POST"),
    ("/empresa", "GET"),
    ("/empresa", "PUT"),
    ("/usuarios", "GET"),
    ("/usuarios", "POST"),
    ("/usuarios/<int:id>", "PUT"),
    ("/usuarios/<int:id>", "DELETE"),
    # etapa 2: login
    ("/auth/login", "POST"),
    ("/auth/me", "GET"),
    # etapa 5: chave do ERP
    ("/erp/configuracao", "GET"),
    ("/erp/configuracao", "PUT"),
    ("/erp/configuracao/chave", "DELETE"),
    # etapa 6: sincronizacao com o ERP
    ("/erp/testar-conexao", "POST"),
    ("/erp/sincronizar", "POST"),
    ("/erp/sincronizacoes", "GET"),
    # etapa 7: lotes
    ("/produtos/<int:id>/lotes", "GET"),
    ("/lotes", "POST"),
    ("/lotes/<int:id>", "PUT"),
    ("/lotes/vencendo", "GET"),
    # etapa 8: historico de movimentacoes
    ("/movimentacoes", "GET"),
    # etapa 9: ordem de saida e previa da venda
    ("/produtos/<int:id>/ordem-saida", "GET"),
    ("/vendas/previa", "GET"),
    # etapa 10: perdas e descartes
    ("/perdas", "POST"),
    ("/perdas", "GET"),
    ("/perdas/resumo", "GET"),
    # etapa 11: curva ABC
    ("/relatorios/curva-abc", "GET"),
    # etapa 12: alertas de excesso e resumo pro selo do menu
    ("/alertas/excesso", "GET"),
    ("/alertas/resumo", "GET"),
    # etapa 13: armazenamento e temperatura
    ("/locais-armazenamento", "GET"),
    ("/locais-armazenamento", "POST"),
    ("/locais-armazenamento/<int:id>", "GET"),
    ("/locais-armazenamento/<int:id>", "PUT"),
    ("/locais-armazenamento/<int:id>", "DELETE"),
    ("/locais-armazenamento/<int:id>/leituras", "GET"),
    ("/locais-armazenamento/<int:id>/leituras", "POST"),
    ("/armazenamento/alertas", "GET"),
}

# o que funciona sem login. /setup tambem, mas so enquanto nao existe empresa (testado em test_empresa)
ROTAS_PUBLICAS = {("/", "GET"), ("/auth/login", "POST"), ("/setup/status", "GET")}


def rotas_registradas():
    for regra in flask_app.url_map.iter_rules():
        if regra.endpoint == "static":
            continue
        for metodo in sorted(regra.methods - {"HEAD", "OPTIONS"}):
            yield regra.rule, metodo


def test_todas_as_rotas_atuais_continuam_registradas():
    assert ROTAS_EXISTENTES - set(rotas_registradas()) == set()


def test_home_sem_login(client_anonimo):
    r = client_anonimo.get("/")
    assert r.status_code == 200
    assert r.get_json() == {"msg": "API do NextStock rodando"}


# percorre TODAS as rotas registradas (inclusive as que forem criadas nas proximas etapas)
@pytest.mark.parametrize("rota, metodo", sorted(set(rotas_registradas()) - ROTAS_PUBLICAS))
def test_toda_rota_nao_publica_exige_login(client_anonimo, admin, rota, metodo):
    url = rota.replace("<int:id>", "1")
    r = client_anonimo.open(url, method=metodo, json={})
    assert r.status_code == 401, f"{metodo} {rota} respondeu {r.status_code} sem login"
