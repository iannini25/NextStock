from models.categoria_model import Categoria


class AtualizarCategoriaService:

    def executar(self, id, dados):
        c = Categoria.buscar_por_id(id)
        if not c:
            return None
        nome = str(dados.get("nome") or "").strip()
        if not nome:
            raise ValueError("nome é obrigatório")
        # so da problema se o nome for de OUTRA categoria
        outra = Categoria.buscar_por_nome(nome)
        if outra and outra.id_categoria != c.id_categoria:
            raise ValueError("já existe categoria com esse nome")

        c.atualizar(nome, dados.get("descricao"))
        return c.virar_dict()
