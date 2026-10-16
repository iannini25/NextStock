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
}


def test_todas_as_rotas_atuais_continuam_registradas():
    registradas = set()
    for regra in flask_app.url_map.iter_rules():
        for metodo in regra.methods - {"HEAD", "OPTIONS"}:
            registradas.add((regra.rule, metodo))
    assert ROTAS_EXISTENTES - registradas == set()


def test_home(client):
    r = client.get("/")
    assert r.status_code == 200
    assert r.get_json() == {"msg": "API do NextStock rodando"}
