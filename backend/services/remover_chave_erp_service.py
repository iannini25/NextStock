from datetime import datetime

from models.configuracao_erp_model import ConfiguracaoErp
from models.empresa_model import Empresa
from services.buscar_configuracao_erp_service import montar_resposta


# apaga so a chave (a URL e o provedor continuam salvos). devolve None se nao tem configuracao.
class RemoverChaveErpService:

    def executar(self, usuario):
        empresa = Empresa.buscar_unica()
        config = ConfiguracaoErp.buscar_da_empresa(empresa.id_empresa) if empresa else None
        if not config:
            return None
        config.chave_criptografada = None
        config.atualizado_em = datetime.now()
        config.atualizado_por = usuario.id_usuario if usuario else None
        config.salvar()
        return montar_resposta(config)
