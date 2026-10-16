from models.empresa_model import Empresa
from services.utils import virar_cnpj, virar_email, virar_texto


class AtualizarEmpresaService:

    def executar(self, dados):
        empresa = Empresa.buscar_unica()
        if not empresa:
            return None
        campos = self.ler_campos(dados)
        empresa.atualizar(**campos)
        return empresa.virar_dict()

    # validacao dos campos da empresa (usada tambem na configuracao inicial)
    @staticmethod
    def ler_campos(dados):
        return {
            "nome": virar_texto(dados.get("nome"), "nome da empresa", 150, obrigatorio=True),
            "nome_fantasia": virar_texto(dados.get("nome_fantasia"), "nome fantasia", 150),
            "cnpj": virar_cnpj(dados.get("cnpj")),
            "email": virar_email(dados.get("email")),
            "telefone": virar_texto(dados.get("telefone"), "telefone", 20),
        }
