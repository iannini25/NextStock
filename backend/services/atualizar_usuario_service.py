from models.usuario_model import Usuario
from services.utils import virar_email, virar_perfil, virar_senha, virar_texto


# o sistema nunca pode ficar sem nenhum administrador ativo (ninguem mais conseguiria administrar)
def conferir_ultimo_admin(usuario, novo_perfil, novo_ativo):
    deixa_de_ser_admin_ativo = usuario.perfil == "admin" and usuario.ativo and (novo_perfil != "admin" or not novo_ativo)
    if not deixa_de_ser_admin_ativo:
        return
    outros = Usuario.query.filter(
        Usuario.perfil == "admin",
        Usuario.ativo.is_(True),
        Usuario.id_usuario != usuario.id_usuario,
    ).count()
    if outros == 0:
        raise ValueError("o sistema precisa ter pelo menos um administrador ativo")


class AtualizarUsuarioService:

    # atual = quem esta fazendo a alteracao (o admin logado)
    def executar(self, id, dados, atual=None):
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

        if atual and atual.id_usuario == usuario.id_usuario:
            if not ativo:
                raise ValueError("você não pode desativar o seu próprio usuário")
            if perfil != "admin" and usuario.perfil == "admin":
                raise ValueError("você não pode tirar o seu próprio acesso de administrador")
        conferir_ultimo_admin(usuario, perfil, ativo)

        senha = dados.get("senha")
        if senha:
            usuario.definir_senha(virar_senha(senha))

        usuario.atualizar(nome, email, perfil, ativo)
        return usuario.virar_dict()
