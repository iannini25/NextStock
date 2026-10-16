import os

# banco so na memoria e assistente sem Gemini.
# tem que vir antes de importar o app: o load_dotenv nao sobrescreve variavel que ja existe.
os.environ["DATABASE_URL"] = "sqlite://"
os.environ["GEMINI_API_KEY"] = ""
os.environ["SECRET_KEY"] = "chave-so-dos-testes"

import urllib.request  # noqa: E402

import pytest  # noqa: E402

from app import app as flask_app  # noqa: E402
from models.database import db  # noqa: E402
from services.atualizar_clima_service import AtualizarClimaService  # noqa: E402
from services.token_service import TokenService  # noqa: E402
from tests.fabricas import criar_usuario  # noqa: E402


@pytest.fixture(autouse=True)
def sem_rede(monkeypatch):
    # o clima nunca baixa nada: quem precisar de clima grava direto na tabela clima_dia
    monkeypatch.setattr(AtualizarClimaService, "executar", lambda self, forcar=False: True)

    def bloquear(*args, **kwargs):
        raise RuntimeError("teste tentou acessar a rede")

    monkeypatch.setattr(urllib.request, "urlopen", bloquear)


@pytest.fixture(autouse=True)
def banco():
    # cada teste comeca com o banco vazio
    with flask_app.app_context():
        db.drop_all()
        db.create_all()
        yield db
        db.session.remove()


# admin ja logado (cria a empresa junto)
@pytest.fixture
def admin():
    return criar_usuario("Admin", "admin@loja.com", perfil="admin")


def logar(usuario):
    c = flask_app.test_client()
    c.environ_base["HTTP_AUTHORIZATION"] = "Bearer " + TokenService().gerar(usuario)
    return c


# cliente logado como admin: e o que a maioria dos testes usa
@pytest.fixture
def client(admin):
    return logar(admin)


# cliente sem token nenhum
@pytest.fixture
def client_anonimo():
    return flask_app.test_client()
