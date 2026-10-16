from datetime import datetime

from models.leitura_temperatura_model import LeituraTemperatura
from models.local_armazenamento_model import LocalArmazenamento
from models.produto_model import Produto

HORAS_SEM_LEITURA = 12  # sem leitura nova ha mais que isso = alerta (padrao do /armazenamento/alertas)

NOMES_STATUS = {
    "ok": "OK",
    "fora_da_faixa": "Fora da faixa",
    "sem_leitura": "Sem leitura",
    "inativo": "Desativado",
}


def graus(valor):
    return f"{float(valor):.1f} °C"


def reais(valor):
    return f"R$ {valor:.2f}"


# produtos guardados no local que tem saldo, com o valor parado neles (lotes x custo do lote)
def produtos_do_local(local):
    itens = []
    for p in Produto.query.filter_by(id_local_armazenamento=local.id_local).order_by(Produto.nome):
        valor = 0.0
        for lote in p.lotes:
            if lote.quantidade_atual > 0:
                custo = lote.custo_unitario if lote.custo_unitario is not None else p.preco_custo
                valor += lote.quantidade_atual * float(custo or 0)
        itens.append({
            "id_produto": p.id_produto,
            "nome": p.nome,
            "unidade": p.unidade,
            "quantidade_estoque": p.quantidade_estoque or 0,
            "valor": round(valor, 2),
        })
    return itens


# como o local esta agora:
#   fora_da_faixa: a ultima leitura saiu da faixa (vale mesmo que seja antiga: e o ultimo estado conhecido)
#   sem_leitura:   nunca teve leitura ou a ultima tem mais de `horas` horas
#   ok / inativo
def situacao(local, horas=HORAS_SEM_LEITURA, agora=None):
    agora = agora or datetime.now()
    ultima = LeituraTemperatura.ultima_do_local(local.id_local)
    horas_desde = round((agora - ultima.data_hora).total_seconds() / 3600, 1) if ultima else None
    if not local.ativo:
        status = "inativo"
    elif ultima and not local.dentro_da_faixa(ultima.temperatura):
        status = "fora_da_faixa"
    elif ultima is None or horas_desde > horas:
        status = "sem_leitura"
    else:
        status = "ok"
    return status, ultima, horas_desde


def mensagem(local, status, ultima, horas_desde, valor):
    faixa = f"faixa {graus(local.temp_min)} a {graus(local.temp_max)}"
    risco = f" {reais(valor)} em produtos em risco." if valor > 0 else ""
    if status == "fora_da_faixa":
        temperatura = float(ultima.temperatura)
        if temperatura > float(local.temp_max):
            desvio = f"{temperatura - float(local.temp_max):.1f} °C acima do máximo"
        else:
            desvio = f"{float(local.temp_min) - temperatura:.1f} °C abaixo do mínimo"
        return (f"{local.nome}: {graus(temperatura)} em {ultima.data_hora:%d/%m %H:%M} ({faixa}) — "
                f"{desvio}.{risco}")
    if status == "sem_leitura":
        if ultima is None:
            return f"{local.nome}: nenhuma leitura de temperatura registrada ainda.{risco}"
        return (f"{local.nome}: sem leitura há {horas_desde:.0f} h (última: {graus(ultima.temperatura)} "
                f"em {ultima.data_hora:%d/%m %H:%M}).{risco}")
    if status == "inativo":
        return f"{local.nome}: local desativado."
    return f"{local.nome}: {graus(ultima.temperatura)}, dentro da {faixa}."


# o local com a situacao, a ultima leitura e os produtos (usado na lista, no detalhe e nos alertas)
def montar(local, horas=HORAS_SEM_LEITURA, com_produtos=False):
    status, ultima, horas_desde = situacao(local, horas)
    produtos = produtos_do_local(local)
    valor = round(sum(p["valor"] for p in produtos), 2)
    dados = local.virar_dict()
    dados.update({
        "status": status,
        "nome_status": NOMES_STATUS[status],
        "prioridade": {"fora_da_faixa": "alta", "sem_leitura": "media"}.get(status),
        "ultima_leitura": ultima.virar_dict() if ultima else None,
        "horas_desde_ultima": horas_desde,
        "quantidade_produtos": len(produtos),
        "valor_em_estoque": valor,
        "mensagem": mensagem(local, status, ultima, horas_desde, valor),
    })
    if com_produtos:
        dados["produtos"] = produtos
    return dados


# id_local_armazenamento que veio no cadastro/edicao do produto. vazio = sem local.
# local desativado so e aceito se ja era o local do produto (editar outro campo nao pode dar erro)
def virar_local(valor, atual=None):
    if valor is None or valor == "":
        return None
    try:
        id_local = int(valor)
    except (TypeError, ValueError):
        raise ValueError("local de armazenamento inválido")
    local = LocalArmazenamento.buscar_por_id(id_local)
    if not local:
        raise ValueError("local de armazenamento não existe")
    if not local.ativo and id_local != atual:
        raise ValueError("esse local de armazenamento está desativado")
    return id_local
