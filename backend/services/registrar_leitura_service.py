from datetime import datetime, timedelta

from models.database import db
from models.leitura_temperatura_model import LeituraTemperatura
from models.local_armazenamento_model import LocalArmazenamento
from services.salvar_local_service import virar_temperatura
from services.situacao_local import montar
from services.utils import usuario_logado


def virar_data_hora(v):
    if v is None or v == "":
        return datetime.now()
    try:
        quando = datetime.fromisoformat(str(v))
    except ValueError:
        raise ValueError("data_hora tem que ser aaaa-mm-ddThh:mm:ss")
    if quando.tzinfo is not None:  # o banco guarda hora local sem fuso
        quando = quando.astimezone().replace(tzinfo=None)
    if quando > datetime.now() + timedelta(minutes=5):
        raise ValueError("data_hora não pode ser no futuro")
    return quando


# grava uma leitura de temperatura. vem da tela (usuario logado, origem manual)
# ou de um dispositivo com a chave do sensor (origem sensor, sem usuario)
class RegistrarLeituraService:

    def executar(self, id_local, dados, origem="manual"):
        local = LocalArmazenamento.buscar_por_id(id_local)
        if not local:
            return None
        if not local.ativo:
            raise ValueError("esse local está desativado")
        temperatura = virar_temperatura(dados.get("temperatura"), "temperatura")
        umidade = dados.get("umidade")
        if umidade is not None and umidade != "":
            try:
                umidade = round(float(str(umidade).replace(",", ".")), 1)
            except (TypeError, ValueError):
                raise ValueError("umidade precisa ser um número")
            if not 0 <= umidade <= 100:
                raise ValueError("umidade tem que ficar entre 0 e 100%")
        else:
            umidade = None

        usuario = usuario_logado() if origem == "manual" else None
        leitura = LeituraTemperatura(
            local=local,
            temperatura=temperatura,
            umidade=umidade,
            data_hora=virar_data_hora(dados.get("data_hora")),
            origem=origem,
            id_usuario=usuario.id_usuario if usuario else None,
        )
        db.session.add(leitura)
        db.session.commit()
        # devolve tambem como o local ficou (o app ja mostra se saiu da faixa)
        return {"leitura": leitura.virar_dict(), "local": montar(local)}
