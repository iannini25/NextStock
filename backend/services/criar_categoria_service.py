from models.categoria_model import Categoria


class CriarCategoriaService:

    def executar(self, dados):
        nome = str(dados.get("nome") or "").strip()
        if not nome:
            raise ValueError("nome é obrigatório")
        if Categoria.buscar_por_nome(nome):
            raise ValueError("já existe categoria com esse nome")

        c = Categoria(nome=nome, descricao=dados.get("descricao"))
        c.salvar()
        return c.virar_dict()
