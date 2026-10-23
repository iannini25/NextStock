from datetime import date, datetime
from services.utils import numero, virar_data

MODULOS = {
    "categorias": {
        "colunas": ["nome", "descricao"],
        "obrigatorias": ["nome"],
        "exemplo": ["Bebidas", "Refrigerantes e sucos"],
    },
    "produtos": {
        "colunas": [
            "nome",
            "id_categoria",
            "codigo_barras",
            "preco_custo",
            "preco_venda",
            "quantidade_estoque",
            "estoque_minimo",
            "unidade",
            "data_validade",
        ],
        "obrigatorias": ["nome", "preco_venda"],
        "exemplo": [
            "Queijo Minas 500g",
            "1",
            "7890000000062",
            "12.00",
            "19.90",
            "20",
            "5",
            "UN",
            "2026-09-10",
        ],
    },
    "vendas": {
        "colunas": ["id_produto", "quantidade", "data_venda"],
        "obrigatorias": ["id_produto", "quantidade"],
        "exemplo": ["1", "3", "2026-08-20"],
    },
    "eventos": {
        "colunas": ["nome", "data_inicio", "data_fim", "impacto_percentual"],
        "obrigatorias": ["nome", "data_inicio", "data_fim"],
        "exemplo": ["Festival local", "2026-09-01", "2026-09-03", "20"],
    },
}

def _texto(v):
    if v is None:
        return ""
    if isinstance(v, datetime):
        return v.date().isoformat()
    if isinstance(v, date):
        return v.isoformat()
    if isinstance(v, float) and v == int(v):
        return str(int(v))
    return str(v).strip()

def _cabecalho(v):
    return _texto(v).lower()

def _numero(v):
    t = _texto(v).replace(" ", "").replace(",", ".")
    return numero(t) if t else None

def _data(v):
    t = _texto(v)
    if not t:
        return None
    if "T" in t:
        t = t.split("T")[0]
    if " " in t:
        t = t.split(" ")[0]
    if "/" in t:
        partes = t.split("/")
        if len(partes) == 3:
            d, m, a = partes
            if len(a) == 4:
                t = f"{a}-{m.zfill(2)}-{d.zfill(2)}"
    return virar_data(t)

def configurar_modulo(modulo):
    chave = (modulo or "").strip().lower()
    if chave not in MODULOS:
        raise ValueError("módulo inválido. use: categorias, produtos, vendas ou eventos")
    return MODULOS[chave]
