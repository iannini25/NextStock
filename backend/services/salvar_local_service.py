from models.database import db
from models.local_armazenamento_model import LocalArmazenamento
from services.utils import virar_texto

TEMP_LIMITE = (-60.0, 80.0)  # faixa que um termometro de loja consegue medir


def virar_temperatura(v, campo, obrigatorio=True):
    if v is None or v == "":
        if obrigatorio:
            raise ValueError(campo + " é obrigatória")
        return None
    try:
        t = round(float(str(v).replace(",", ".")), 1)
    except (TypeError, ValueError):
        raise ValueError(campo + " precisa ser um número")
    if not TEMP_LIMITE[0] <= t <= TEMP_LIMITE[1]:
        raise ValueError(f"{campo} tem que ficar entre {TEMP_LIMITE[0]:.0f} e {TEMP_LIMITE[1]:.0f} °C")
    return t


# cria (id=None) ou edita um local de armazenamento. so admin (ver armazenamento_controller)
class SalvarLocalService:

    def executar(self, dados, id=None):
        local = None
        if id is not None:
            local = LocalArmazenamento.buscar_por_id(id)
            if not local:
                return None

        nome = virar_texto(dados.get("nome"), "nome", 100, obrigatorio=True)
        repetido = LocalArmazenamento.buscar_por_nome(nome)
        if repetido and (local is None or repetido.id_local != local.id_local):
            raise ValueError("já existe um local com esse nome")

        tipo = str(dados.get("tipo") or "refrigerado").strip().lower()
        if tipo not in LocalArmazenamento.TIPOS:
            raise ValueError("tipo tem que ser ambiente, refrigerado ou congelado")

        # sem faixa informada, usa a sugerida pro tipo
        padrao_min, padrao_max = LocalArmazenamento.FAIXAS_PADRAO[tipo]
        temp_min = virar_temperatura(dados.get("temp_min"), "temperatura mínima", obrigatorio=False)
        temp_max = virar_temperatura(dados.get("temp_max"), "temperatura máxima", obrigatorio=False)
        temp_min = padrao_min if temp_min is None else temp_min
        temp_max = padrao_max if temp_max is None else temp_max
        if temp_min >= temp_max:
            raise ValueError("a temperatura mínima tem que ser menor que a máxima")

        if local is None:
            local = LocalArmazenamento(ativo=True)
            db.session.add(local)
        elif "ativo" in dados:  # na edicao da pra reativar (ou desativar) pelo campo ativo
            local.ativo = bool(dados.get("ativo"))
        local.nome = nome
        local.tipo = tipo
        local.temp_min = temp_min
        local.temp_max = temp_max
        db.session.commit()
        return local.virar_dict()
