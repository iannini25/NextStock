from sqlalchemy import inspect, text

COLUNA = "id_local_armazenamento"


class MigrarArmazenamento:
    """Adapta bancos antigos antes de qualquer consulta de Produto.

    create_all cria tabelas, mas não acrescenta colunas a tabelas existentes.
    A coluna é opcional para preservar produtos cadastrados antes dos locais.
    """

    def __init__(self, engine):
        self.engine = engine

    def executar(self):
        colunas = {c["name"] for c in inspect(self.engine).get_columns("produto")}
        if COLUNA in colunas:
            return False

        mysql = self.engine.dialect.name == "mysql"
        definicao = "INT NULL" if mysql else "INTEGER REFERENCES local_armazenamento(id_local)"
        with self.engine.begin() as conexao:
            conexao.execute(text(f"ALTER TABLE produto ADD COLUMN {COLUNA} {definicao}"))

        # Mantém a compatibilidade com tabelas MySQL antigas sem suporte a FK.
        # Falhas ao criar a coluna continuam interrompendo a inicialização.
        if mysql:
            try:
                with self.engine.begin() as conexao:
                    conexao.execute(text(
                        "ALTER TABLE produto ADD CONSTRAINT fk_produto_local_armazenamento "
                        f"FOREIGN KEY ({COLUNA}) REFERENCES local_armazenamento(id_local)"))
            except Exception as erro:  # noqa: BLE001
                print("aviso: coluna produto.id_local_armazenamento criada sem chave estrangeira:", erro)
        return True
