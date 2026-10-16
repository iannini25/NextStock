from models.empresa_model import Empresa
from models.usuario_model import Usuario
from services.utils import virar_email, virar_perfil, virar_senha, virar_texto


class CriarUsuarioService:

    def executar(self, dados):
        empresa = Empresa.buscar_unica()
        if not empresa:
            raise ValueError("configure a empresa antes de cadastrar usuários")
        campos = self.ler_campos(dados)
        usuario = Usuario(
            id_empresa=empresa.id_empresa,
            nome=campos["nome"],
            email=campos["email"],
            perfil=campos["perfil"],
            ativo=True,
        )
        usuario.definir_senha(campos["senha"])
        usuario.salvar()
        return usuario.virar_dict()

    # validacao de um usuario novo (usada tambem pro admin da configuracao inicial)
    @staticmethod
    def ler_campos(dados):
        nome = virar_texto(dados.get("nome"), "nome", 100, obrigatorio=True)
        email = virar_email(dados.get("email"))
        if not email:
            raise ValueError("e-mail é obrigatório")
        if Usuario.buscar_por_email(email):
            raise ValueError("já existe usuário com esse e-mail")
        return {
            "nome": nome,
            "email": email,
            "perfil": virar_perfil(dados.get("perfil")),
            "senha": virar_senha(dados.get("senha")),
        }
