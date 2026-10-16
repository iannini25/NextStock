from models.local_armazenamento_model import LocalArmazenamento
from services.situacao_local import HORAS_SEM_LEITURA, montar
from services.utils import inteiro


# locais ativos com problema: ultima leitura fora da faixa (prioridade alta) ou sem leitura recente (media),
# com os produtos guardados neles e o valor em risco. os mais graves e de maior valor primeiro
class AlertasTemperaturaService:

    def executar(self, horas=HORAS_SEM_LEITURA):
        horas = inteiro(horas)
        horas = HORAS_SEM_LEITURA if horas is None else horas
        if horas < 1 or horas > 168:
            raise ValueError("horas tem que ser entre 1 e 168")
        alertas = []
        for local in LocalArmazenamento.listar():
            dados = montar(local, horas, com_produtos=True)
            if dados["status"] in ("fora_da_faixa", "sem_leitura"):
                dados["valor_em_risco"] = dados["valor_em_estoque"]
                alertas.append(dados)
        alertas.sort(key=lambda a: (a["prioridade"] != "alta", -a["valor_em_risco"], a["nome"]))
        return alertas
