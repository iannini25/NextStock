from datetime import date


# vira numero, se vier vazio devolve None
def numero(v):
    if v is None or v == "":
        return None
    try:
        n = float(v)
    except (TypeError, ValueError):
        raise ValueError("valor precisa ser numero")
    if n < 0:
        raise ValueError("valor nao pode ser negativo")
    return n


def inteiro(v):
    if v is None or v == "":
        return None
    try:
        n = int(v)
    except (TypeError, ValueError):
        raise ValueError("valor precisa ser numero inteiro")
    if n < 0:
        raise ValueError("valor nao pode ser negativo")
    return n


# data no formato aaaa-mm-dd
def virarData(v):
    if v is None or v == "":
        return None
    try:
        a, m, d = str(v).split("-")
        return date(int(a), int(m), int(d))
    except (ValueError, AttributeError):
        raise ValueError("data tem que ser aaaa-mm-dd")
