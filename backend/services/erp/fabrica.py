from models.configuracao_erp_model import ConfiguracaoErp
from models.empresa_model import Empresa
from services.cripto_service import ChaveDeCriptografiaFaltando, CriptoService
from services.erp.conector_generico import ConectorErpGenerico

# provedor (como fica salvo na configuracao) -> classe que fala com ele
CONECTORES = {
    "generico": ConectorErpGenerico,
}


# monta o conector com a configuracao salva (Etapa 5). erros de configuracao viram ValueError com a mensagem pra tela
class CriarConectorErpService:
    def executar(self):
        empresa = Empresa.buscar_unica()
        config = ConfiguracaoErp.buscar_da_empresa(empresa.id_empresa) if empresa else None
        if not config:
            raise ValueError("configure a integração com o ERP primeiro (URL e chave)")
        if not config.chave_criptografada:
            raise ValueError("cadastre a chave da API do ERP primeiro")
        try:
            chave = CriptoService().descriptografar(config.chave_criptografada)
        except ChaveDeCriptografiaFaltando as e:
            raise ValueError(str(e))
        if chave is None:
            raise ValueError("a chave salva não abre com a ERP_CHAVE_CRIPTOGRAFIA atual. Cadastre a chave de novo.")
        classe = CONECTORES.get(config.provedor)
        if not classe:
            raise ValueError("provedor de ERP sem conector: " + config.provedor)
        return classe(config.url_base, chave), config


def criar_conector():
    return CriarConectorErpService().executar()
