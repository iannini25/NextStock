"""Compatibility import; database migrations live in infrastructure."""
from infrastructure.migracao_armazenamento import COLUNA, MigrarArmazenamento


def garantir_coluna_local_produto(engine):
    return MigrarArmazenamento(engine).executar()
