import os

# banco so na memoria e assistente sem Gemini.
# tem que vir antes de importar o app: o load_dotenv nao sobrescreve variavel que ja existe.
os.environ["DATABASE_URL"] = "sqlite://"
os.environ["GEMINI_API_KEY"] = ""

import urllib.request  # noqa: E402

import pytest  # noqa: E402

from app import app as flask_app  # noqa: E402
from models.database import db  # noqa: E402
from services.atualizar_clima_service import AtualizarClimaService  # noqa: E402


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


@pytest.fixture
def client():
    return flask_app.test_client()
