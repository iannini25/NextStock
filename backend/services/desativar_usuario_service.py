from models.usuario_model import Usuario
from services.atualizar_usuario_service import conferir_ultimo_admin


# nao apaga: so desativa (o usuario desativado nao vai conseguir entrar no sistema)
class DesativarUsuarioService:

    # atual = quem esta desativando (o admin logado)
    def executar(self, id, atual=None):
        usuario = Usuario.buscar_por_id(id)
        if not usuario:
            return False
        if atual and atual.id_usuario == usuario.id_usuario:
            raise ValueError("você não pode desativar o seu próprio usuário")
        conferir_ultimo_admin(usuario, usuario.perfil, False)
        usuario.desativar()
        return True
