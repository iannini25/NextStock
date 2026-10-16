from models.usuario_model import Usuario


class ListarUsuariosService:

    def executar(self):
        return [u.virar_dict() for u in Usuario.listar_todos()]
