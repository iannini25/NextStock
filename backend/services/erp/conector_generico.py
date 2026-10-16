import json
import socket
import urllib.error
import urllib.parse
import urllib.request

from services.erp.conector_erp import ConectorErp, ErroErp


# ERP generico com API REST (o ERP simulado de tools/erp_simulado segue esse formato):
#   GET {url}/status                    -> qualquer JSON (so confere se responde)
#   GET {url}/produtos?desde=<ISO 8601> -> lista de produtos no formato do /erp/importar
#   GET {url}/vendas?desde=<ISO 8601>   -> lista de vendas com id_externo, codigo_barras, quantidade, data_venda
# autenticacao: header "Authorization: Bearer <chave>"
class ConectorErpGenerico(ConectorErp):

    TEMPO_LIMITE = 15  # segundos

    def testar_conexao(self):
        return self._get("/status")

    def buscar_produtos(self, desde):
        return self._lista("/produtos", desde)

    def buscar_vendas(self, desde):
        return self._lista("/vendas", desde)

    def _lista(self, caminho, desde):
        params = {"desde": desde.isoformat(timespec="seconds")} if desde else None
        dados = self._get(caminho, params)
        if not isinstance(dados, list):
            raise ErroErp(f"resposta inesperada do ERP em {caminho}: era pra vir uma lista")
        return dados

    def _get(self, caminho, params=None):
        url = self.url_base + caminho
        if params:
            url += "?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, headers={
            "Authorization": "Bearer " + self.chave,
            "Accept": "application/json",
            "User-Agent": "NextStock/1.0",
        })
        try:
            with urllib.request.urlopen(req, timeout=self.TEMPO_LIMITE) as resp:
                corpo = resp.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            if e.code in (401, 403):
                raise ErroErp(f"o ERP recusou a chave da API (HTTP {e.code}): confira a chave cadastrada")
            if e.code == 404:
                raise ErroErp(f"endereço não encontrado no ERP (HTTP 404): confira a URL ({url})")
            raise ErroErp(f"o ERP respondeu com erro (HTTP {e.code})")
        except (TimeoutError, socket.timeout):
            raise ErroErp(f"o ERP demorou mais de {self.TEMPO_LIMITE} segundos pra responder")
        except urllib.error.URLError as e:
            motivo = e.reason if isinstance(e.reason, str) else type(e.reason).__name__
            if isinstance(e.reason, (TimeoutError, socket.timeout)):
                raise ErroErp(f"o ERP demorou mais de {self.TEMPO_LIMITE} segundos pra responder")
            raise ErroErp(f"não foi possível conectar ao ERP em {self.url_base} ({motivo}). Ele está no ar?")
        except OSError as e:
            raise ErroErp(f"não foi possível conectar ao ERP em {self.url_base} ({type(e).__name__})")
        try:
            return json.loads(corpo)
        except json.JSONDecodeError:
            raise ErroErp(f"o ERP respondeu algo que não é JSON em {caminho}")
