from sqlalchemy import inspect, text

COLUNA = "id_local_armazenamento"


# o db.create_all() cria tabela nova, mas nao mexe em tabela que ja existe.
# produto ganhou a coluna id_local_armazenamento (aceita nulo): se o banco e antigo, cria ela aqui.
# pode rodar quantas vezes quiser: se a coluna ja existe, nao faz nada. devolve True quando criou.
def garantir_coluna_local_produto(engine):
    colunas = {c["name"] for c in inspect(engine).get_columns("produto")}
    if COLUNA in colunas:
        return False

    with engine.begin() as conexao:
        if engine.dialect.name == "mysql":
            conexao.execute(text(f"ALTER TABLE produto ADD COLUMN {COLUNA} INT NULL"))
        else:
            conexao.execute(text(
                f"ALTER TABLE produto ADD COLUMN {COLUNA} INTEGER REFERENCES local_armazenamento(id_local)"))

    # no mysql a chave estrangeira entra separada. se nao der (tabela antiga sem InnoDB, por exemplo),
    # a coluna continua funcionando: so fica sem a trava do banco
    if engine.dialect.name == "mysql":
        try:
            with engine.begin() as conexao:
                conexao.execute(text(
                    f"ALTER TABLE produto ADD CONSTRAINT fk_produto_local_armazenamento "
                    f"FOREIGN KEY ({COLUNA}) REFERENCES local_armazenamento(id_local)"))
        except Exception as e:  # noqa: BLE001
            print("aviso: coluna produto.id_local_armazenamento criada sem chave estrangeira:", e)
    return True
