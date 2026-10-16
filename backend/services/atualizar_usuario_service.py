from models.usuario_model import Usuario
from services.utils import virar_email, virar_perfil, virar_senha, virar_texto


class AtualizarUsuarioService:

    def executar(self, id, dados):
        usuario = Usuario.buscar_por_id(id)
        if not usuario:
            return None

        nome = virar_texto(dados.get("nome"), "nome", 100, obrigatorio=True)
        email = virar_email(dados.get("email"))
        if not email:
            raise ValueError("e-mail é obrigatório")
        outro = Usuario.buscar_por_email(email)
        if outro and outro.id_usuario != usuario.id_usuario:
            raise ValueError("já existe usuário com esse e-mail")
        perfil = virar_perfil(dados.get("perfil"), padrao=usuario.perfil)

        # ativo e senha sao opcionais: se nao vierem, ficam como estao
        ativo = usuario.ativo
        if "ativo" in dados:
            if not isinstance(dados["ativo"], bool):
                raise ValueError("ativo tem que ser true ou false")
            ativo = dados["ativo"]
        senha = dados.get("senha")
        if senha:
            usuario.definir_senha(virar_senha(senha))

        usuario.atualizar(nome, email, perfil, ativo)
        return usuario.virar_dict()
