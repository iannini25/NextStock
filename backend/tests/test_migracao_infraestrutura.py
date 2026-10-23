from unittest.mock import MagicMock

import pytest
from sqlalchemy import create_engine, event, inspect, text
from sqlalchemy.exc import IntegrityError, OperationalError

from infrastructure.migracao_armazenamento import MigrarArmazenamento
from services.migracao_armazenamento import garantir_coluna_local_produto


def test_sqlite_preserva_dados_e_aplica_fk_no_banco_antigo():
    engine = create_engine("sqlite://")

    @event.listens_for(engine, "connect")
    def ativar_fk(conexao, _):
        conexao.execute("PRAGMA foreign_keys=ON")

    try:
        with engine.begin() as conexao:
            conexao.execute(text("CREATE TABLE local_armazenamento (id_local INTEGER PRIMARY KEY)"))
            conexao.execute(text("CREATE TABLE produto (id_produto INTEGER PRIMARY KEY, nome TEXT)"))
            conexao.execute(text("INSERT INTO produto VALUES (1, 'Leite')"))
            conexao.execute(text("INSERT INTO local_armazenamento VALUES (7)"))

        assert MigrarArmazenamento(engine).executar() is True
        assert garantir_coluna_local_produto(engine) is False
        with engine.begin() as conexao:
            assert conexao.execute(text("SELECT nome, id_local_armazenamento FROM produto")).one() == ("Leite", None)
            conexao.execute(text("UPDATE produto SET id_local_armazenamento=7"))
        with pytest.raises(IntegrityError), engine.begin() as conexao:
            conexao.execute(text("UPDATE produto SET id_local_armazenamento=999"))
        assert inspect(engine).get_foreign_keys("produto")[0]["referred_table"] == "local_armazenamento"
    finally:
        engine.dispose()


def banco_mysql(monkeypatch, colunas=()):
    engine = MagicMock()
    engine.dialect.name = "mysql"
    inspetor = MagicMock()
    inspetor.get_columns.return_value = [{"name": nome} for nome in colunas]
    monkeypatch.setattr("infrastructure.migracao_armazenamento.inspect", lambda _: inspetor)
    conexao = engine.begin.return_value.__enter__.return_value
    return engine, conexao


def test_mysql_cria_coluna_opcional_e_fk_em_transacoes_separadas(monkeypatch):
    engine, conexao = banco_mysql(monkeypatch)
    assert MigrarArmazenamento(engine).executar() is True
    comandos = [str(chamada.args[0]) for chamada in conexao.execute.call_args_list]
    assert comandos == [
        "ALTER TABLE produto ADD COLUMN id_local_armazenamento INT NULL",
        "ALTER TABLE produto ADD CONSTRAINT fk_produto_local_armazenamento "
        "FOREIGN KEY (id_local_armazenamento) REFERENCES local_armazenamento(id_local)",
    ]
    assert engine.begin.call_count == 2


def test_mysql_sem_suporte_a_fk_mantem_coluna_e_avisa(monkeypatch, capsys):
    engine, conexao = banco_mysql(monkeypatch)
    conexao.execute.side_effect = [None, OperationalError("FK", {}, Exception("sem suporte"))]
    assert MigrarArmazenamento(engine).executar() is True
    assert "criada sem chave estrangeira" in capsys.readouterr().out


def test_falha_na_coluna_interrompe_inicializacao(monkeypatch):
    engine, conexao = banco_mysql(monkeypatch)
    conexao.execute.side_effect = OperationalError("ALTER", {}, Exception("sem permissao"))
    with pytest.raises(OperationalError):
        MigrarArmazenamento(engine).executar()
    assert conexao.execute.call_count == 1


def test_coluna_existente_nao_executa_ddl(monkeypatch):
    engine, _ = banco_mysql(monkeypatch, ["id_produto", "id_local_armazenamento"])
    assert MigrarArmazenamento(engine).executar() is False
    engine.begin.assert_not_called()
