from models.categoria_model import Categoria


class AtualizarCategoriaService:

    def executar(self, id, dados):
        c = Categoria.buscar_por_id(id)
        if not c:
            return None
        if not dados.get("nome"):
            raise ValueError("nome é obrigatório")

        c.atualizar(dados["nome"], dados.get("descricao"))
        return c.virar_dict()
