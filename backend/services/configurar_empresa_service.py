from models.database import db
from models.empresa_model import Empresa
from models.usuario_model import Usuario
from services.atualizar_empresa_service import AtualizarEmpresaService
from services.criar_usuario_service import CriarUsuarioService


# configuracao inicial: cria a empresa e o primeiro administrador juntos.
# so funciona uma vez; depois disso devolve None (a controller responde 409).
class ConfigurarEmpresaService:

    def executar(self, dados):
        if Empresa.buscar_unica():
            return None

        dados_empresa = dados.get("empresa")
        dados_admin = dados.get("admin")
        if not isinstance(dados_empresa, dict) or not isinstance(dados_admin, dict):
            raise ValueError("mande os dados da empresa e do administrador")

        # valida tudo antes de gravar qualquer coisa
        campos_empresa = AtualizarEmpresaService.ler_campos(dados_empresa)
        campos_admin = CriarUsuarioService.ler_campos(dados_admin)

        empresa = Empresa(**campos_empresa)
        db.session.add(empresa)
        db.session.flush()  # gera o id da empresa sem fechar a transacao

        admin = Usuario(
            id_empresa=empresa.id_empresa,
            nome=campos_admin["nome"],
            email=campos_admin["email"],
            perfil="admin",
            ativo=True,
        )
        admin.definir_senha(campos_admin["senha"])
        db.session.add(admin)
        db.session.commit()  # empresa e admin entram juntos ou nenhum entra

        return {"empresa": empresa.virar_dict(), "admin": admin.virar_dict()}
