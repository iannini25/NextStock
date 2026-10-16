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


def test_login_ignora_maiusculas_e_espacos_no_email(client_anonimo, admin):
    assert entrar(client_anonimo, "  ADMIN@Loja.com ", SENHA_PADRAO).status_code == 200


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


@pytest.mark.parametrize("dados", [{}, {"email": "admin@loja.com"}, {"senha": "x"}])
def test_login_sem_email_ou_senha(client_anonimo, dados):
    r = client_anonimo.post("/auth/login", json=dados)
    assert r.status_code == 400
    assert r.get_json() == {"erro": "informe o e-mail e a senha"}


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


def test_token_adulterado(client_anonimo, admin):
    token = TokenService().gerar(admin)
    adulterado = token[:-2] + ("AA" if token[-2:] != "AA" else "BB")
    r = client_anonimo.get("/produtos", headers={"Authorization": "Bearer " + adulterado})
    assert r.status_code == 401
    assert r.get_json() == {"erro": "sua sessão expirou, entre de novo"}


def test_token_vence_em_12_horas(client_anonimo, admin, monkeypatch):
    agora = time.time()
    with monkeypatch.context() as m:
        m.setattr(time, "time", lambda: agora - 12 * 60 * 60 - 60)  # gerado ha 12h01
        vencido = TokenService().gerar(admin)
    with monkeypatch.context() as m:
        m.setattr(time, "time", lambda: agora - 11 * 60 * 60)  # gerado ha 11h
        valido = TokenService().gerar(admin)

    assert client_anonimo.get("/produtos", headers={"Authorization": "Bearer " + vencido}).status_code == 401
    assert client_anonimo.get("/produtos", headers={"Authorization": "Bearer " + valido}).status_code == 200


def test_token_de_outra_chave_nao_vale(client_anonimo, admin, monkeypatch):
    monkeypatch.setenv("SECRET_KEY", "outra-chave")
    token = TokenService().gerar(admin)
    monkeypatch.setenv("SECRET_KEY", "chave-so-dos-testes")
    assert client_anonimo.get("/produtos", headers={"Authorization": "Bearer " + token}).status_code == 401


def test_usuario_desativado_perde_o_acesso_na_hora(client):
    maria = criar_usuario("Maria", "maria@loja.com")
    sessao_maria = logar(maria)
    assert sessao_maria.get("/produtos").status_code == 200

    client.delete(f"/usuarios/{maria.id_usuario}")
    assert sessao_maria.get("/produtos").status_code == 401


def test_preflight_do_cors_passa_sem_token(client_anonimo):
    r = client_anonimo.options("/produtos", headers={
        "Origin": "http://localhost:5555",
        "Access-Control-Request-Method": "GET",
        "Access-Control-Request-Headers": "authorization",
    })
    assert r.status_code == 200
    assert r.headers.get("Access-Control-Allow-Origin")
    assert "authorization" in r.headers.get("Access-Control-Allow-Headers", "").lower()


def test_chave_de_exemplo_do_env_nao_e_usada(monkeypatch, admin):
    # quem copia o .env.example sem trocar a chave nao fica com tokens falsificaveis
    monkeypatch.setenv("SECRET_KEY", "troque_por_um_texto_aleatorio")
    from itsdangerous import URLSafeTimedSerializer

    falsificado = URLSafeTimedSerializer("troque_por_um_texto_aleatorio", salt="nextstock-login").dumps({"id": admin.id_usuario})
    assert TokenService().ler(falsificado) is None
