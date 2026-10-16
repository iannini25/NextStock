from models.usuario_model import Usuario


# nao apaga: so desativa (o usuario desativado nao vai conseguir entrar no sistema)
class DesativarUsuarioService:

    def executar(self, id):
        usuario = Usuario.buscar_por_id(id)
        if not usuario:
            return False
        usuario.desativar()
        return True
