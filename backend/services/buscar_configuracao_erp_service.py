from models.configuracao_erp_model import ConfiguracaoErp
from models.empresa_model import Empresa
from services.cripto_service import ChaveDeCriptografiaFaltando, CriptoService


# so os 4 ultimos caracteres aparecem
def mascarar(chave):
    if len(chave) <= 4:
        return "••••"
    return "••••" + chave[-4:]


# o que a API devolve sobre a configuracao. a chave nunca sai inteira.
def montar_resposta(config):
    resposta = {
        "configurado": config is not None,
        "provedores": ConfiguracaoErp.PROVEDORES,
        "provedor": config.provedor if config else "generico",
        "url_base": config.url_base if config else None,
        "ativo": config.ativo if config else False,
        "possui_chave": bool(config and config.chave_criptografada),
        "chave_mascarada": None,
        "aviso": None,
        "atualizado_em": config.atualizado_em.isoformat(timespec="minutes") if config and config.atualizado_em else None,
        "atualizado_por": config.usuario.nome if config and config.usuario else None,
    }
    if resposta["possui_chave"]:
        try:
            chave = CriptoService().descriptografar(config.chave_criptografada)
        except ChaveDeCriptografiaFaltando as e:
            resposta["aviso"] = str(e)
        else:
            if chave is None:
                resposta["aviso"] = "a chave salva não abre com a ERP_CHAVE_CRIPTOGRAFIA atual. Cadastre a chave de novo."
            else:
                resposta["chave_mascarada"] = mascarar(chave)
    return resposta


class BuscarConfiguracaoErpService:

    def executar(self):
        empresa = Empresa.buscar_unica()
        config = ConfiguracaoErp.buscar_da_empresa(empresa.id_empresa) if empresa else None
        return montar_resposta(config)
