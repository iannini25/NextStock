from datetime import datetime
from urllib.parse import urlparse

from models.configuracao_erp_model import ConfiguracaoErp
from models.empresa_model import Empresa
from services.buscar_configuracao_erp_service import montar_resposta
from services.cripto_service import CriptoService


def virar_url(v):
    url = str(v or "").strip().rstrip("/")
    if not url:
        raise ValueError("informe a URL do ERP")
    if len(url) > 255:
        raise ValueError("URL pode ter no máximo 255 caracteres")
    partes = urlparse(url)
    if partes.scheme not in ("http", "https") or not partes.netloc or " " in url:
        raise ValueError("URL inválida: use o endereço completo, ex.: https://erp.minhaloja.com/api")
    return url


class SalvarConfiguracaoErpService:

    # chave_api em branco = mantem a chave que ja estava salva
    def executar(self, dados, usuario):
        empresa = Empresa.buscar_unica()
        if not empresa:
            raise ValueError("configure a empresa primeiro")

        provedor = str(dados.get("provedor") or "generico").strip().lower()
        if provedor not in ConfiguracaoErp.PROVEDORES:
            raise ValueError("provedor inválido. use: " + ", ".join(ConfiguracaoErp.PROVEDORES))
        url_base = virar_url(dados.get("url_base"))
        ativo = dados.get("ativo", True)
        if not isinstance(ativo, bool):
            raise ValueError("ativo tem que ser true ou false")
        chave = str(dados.get("chave_api") or "").strip()
        if len(chave) > 500:
            raise ValueError("chave da API pode ter no máximo 500 caracteres")

        config = ConfiguracaoErp.buscar_da_empresa(empresa.id_empresa)
        if not config and not chave:
            raise ValueError("informe a chave da API do ERP")

        # criptografa antes de mexer em qualquer coisa (se faltar a chave do .env, nada e gravado)
        chave_criptografada = CriptoService().criptografar(chave) if chave else None

        if not config:
            config = ConfiguracaoErp(id_empresa=empresa.id_empresa)
        config.provedor = provedor
        config.url_base = url_base
        config.ativo = ativo
        if chave_criptografada:
            config.chave_criptografada = chave_criptografada
        config.atualizado_em = datetime.now()
        config.atualizado_por = usuario.id_usuario if usuario else None
        config.salvar()
        return montar_resposta(config)
