import re
from datetime import date

from flask import g, has_request_context


# quem esta logado na requisicao atual (None fora de uma requisicao, ex.: scripts e migracao)
def usuario_logado():
    return g.get("usuario") if has_request_context() else None


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
def virar_data(v):
    if v is None or v == "":
        return None
    try:
        a, m, d = str(v).split("-")
        return date(int(a), int(m), int(d))
    except (ValueError, AttributeError):
        raise ValueError("data tem que ser aaaa-mm-dd")


# texto sem espaco nas pontas; vazio vira None (ou erro, se for obrigatorio)
def virar_texto(v, campo, maximo, obrigatorio=False):
    texto = str(v).strip() if v is not None else ""
    if not texto:
        if obrigatorio:
            raise ValueError(campo + " é obrigatório")
        return None
    if len(texto) > maximo:
        raise ValueError(campo + " pode ter no máximo " + str(maximo) + " caracteres")
    return texto


# e-mail simples (algo@algo.algo, sem espaco), sempre em minusculo
def virar_email(v):
    email = virar_texto(v, "e-mail", 150)
    if email is None:
        return None
    email = email.lower()
    if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
        raise ValueError("e-mail inválido")
    return email


# cnpj so com os numeros; aceita com ou sem pontuacao
def virar_cnpj(v):
    if v is None or str(v).strip() == "":
        return None
    digitos = re.sub(r"\D", "", str(v))
    if len(digitos) != 14:
        raise ValueError("CNPJ tem que ter 14 números")
    return digitos


def virar_senha(v):
    senha = "" if v is None else str(v)
    if len(senha) < 8:
        raise ValueError("senha tem que ter pelo menos 8 caracteres")
    if len(senha) > 128:
        raise ValueError("senha pode ter no máximo 128 caracteres")
    return senha


def virar_perfil(v, padrao="usuario"):
    perfil = str(v).strip().lower() if v else padrao
    if perfil not in ("admin", "usuario"):
        raise ValueError("perfil tem que ser admin ou usuario")
    return perfil
