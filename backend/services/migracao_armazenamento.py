"""Compatibility import; database migrations live in database."""
from database.migracao_armazenamento import COLUNA, MigrarArmazenamento


def garantir_coluna_local_produto(engine):
    return MigrarArmazenamento(engine).executar()
