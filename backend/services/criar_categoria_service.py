from models.categoria_model import Categoria


class CriarCategoriaService:

    def executar(self, dados):
        if not dados.get("nome"):
            raise ValueError("nome é obrigatório")

        c = Categoria(nome=dados["nome"], descricao=dados.get("descricao"))
        c.salvar()
        return c.virar_dict()
