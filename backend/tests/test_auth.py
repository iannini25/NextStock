import time

import pytest

from services.token_service import TokenService
from tests.conftest import logar
from tests.fabricas import SENHA_PADRAO, criar_usuario


def entrar(client, email, senha):
    return client.post("/auth/login", json={"email": email, "senha": senha})


def test_login_devolve_token_usuario_e_empresa(client_anonimo, admin):
    r = entrar(client_anonimo, "admin@loja.com", SENHA_PADRAO)
    assert r.status_code == 200
    corpo = r.get_json()
    assert set(corpo) == {"token", "usuario", "empresa"}
    assert corpo["usuario"] == admin.virar_dict()
    assert "senha_hash" not in corpo["usuario"]
    assert corpo["empresa"]["nome"] == "Mercado Bom Preço LTDA"

    # o token abre as rotas protegidas
    eu = client_anonimo.get("/auth/me", headers={"Authorization": "Bearer " + corpo["token"]})
    assert eu.status_code == 200
    assert eu.get_json()["usuario"]["email"] == "admin@loja.com"
    assert eu.get_json()["empresa"]["id_empresa"] == admin.id_empresa


@pytest.mark.parametrize("email, senha", [
    ("admin@loja.com", "senha-errada"),
    ("ninguem@loja.com", SENHA_PADRAO),
    ("inativo@loja.com", SENHA_PADRAO),
])
def test_login_invalido_tem_sempre_a_mesma_resposta(client_anonimo, admin, email, senha):
    criar_usuario("Inativo", "inativo@loja.com", ativo=False)
    r = entrar(client_anonimo, email, senha)
    assert r.status_code == 401
    assert r.get_json() == {"erro": "e-mail ou senha inválidos"}


def test_rota_protegida_sem_token(client_anonimo):
    r = client_anonimo.get("/produtos")
    assert r.status_code == 401
    assert r.get_json() == {"erro": "faça login para continuar"}


@pytest.mark.parametrize("cabecalho", [
    "Bearer token-inventado",
    "Bearer ",
    "Basic YWRtaW46c2VuaGE=",
])
def test_token_invalido(client_anonimo, admin, cabecalho):
    r = client_anonimo.get("/produtos", headers={"Authorization": cabecalho})
    assert r.status_code == 401


def test_usuario_desativado_perde_o_acesso_na_hora(client):
    maria = criar_usuario("Maria", "maria@loja.com")
    sessao_maria = logar(maria)
    assert sessao_maria.get("/produtos").status_code == 200

    client.delete(f"/usuarios/{maria.id_usuario}")
    assert sessao_maria.get("/produtos").status_code == 401
