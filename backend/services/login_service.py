from werkzeug.security import check_password_hash, generate_password_hash

from models.usuario_model import Usuario
from services.token_service import TokenService

# hash qualquer pra conferir quando o e-mail nao existe: assim a resposta demora o mesmo tempo
# e ninguem descobre quais e-mails estao cadastrados pelo tempo de resposta
_HASH_FALSO = generate_password_hash("senha-que-nao-existe")


class LoginService:

    # devolve token + usuario + empresa, ou None se o login nao vale
    # (e-mail inexistente, senha errada ou usuario desativado: a resposta e a mesma pros tres)
    def executar(self, dados):
        email = str(dados.get("email") or "").strip().lower()
        senha = str(dados.get("senha") or "")
        if not email or not senha:
            raise ValueError("informe o e-mail e a senha")

        usuario = Usuario.buscar_por_email(email)
        if not usuario:
            check_password_hash(_HASH_FALSO, senha)
            return None
        if not usuario.conferir_senha(senha) or not usuario.ativo:
            return None

        return {
            "token": TokenService().gerar(usuario),
            "usuario": usuario.virar_dict(),
            "empresa": usuario.empresa.virar_dict(),
        }
