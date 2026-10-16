"""ERP simulado, so pra desenvolvimento e teste da integracao do NextStock.

Faz o papel de um ERP de verdade: tem produtos e vendas e responde no formato do conector "ERP genérico".

Como usar:
    python tools/erp_simulado/erp_simulado.py

No NextStock (tela Integração ERP):
    URL da API do ERP:  http://127.0.0.1:5001
    Chave da API:       chave-do-erp-simulado-123   (ou o valor de ERP_SIMULADO_CHAVE, se definir)

Rotas (todas pedem o header "Authorization: Bearer <chave>"):
    GET  /status                      -> confere se esta no ar
    GET  /produtos?desde=<ISO 8601>   -> produtos alterados depois de "desde" (sem desde = todos)
    GET  /vendas?desde=<ISO 8601>     -> vendas registradas depois de "desde"
    POST /simular/venda               -> registra uma venda nova agora (pra testar a sincronizacao incremental)
                                         corpo opcional: {"codigo_barras": "...", "quantidade": 2}
"""
import os
from datetime import date, datetime, timedelta

from flask import Flask, jsonify, request

CHAVE = os.getenv("ERP_SIMULADO_CHAVE", "chave-do-erp-simulado-123")
PORTA = int(os.getenv("ERP_SIMULADO_PORTA", "5001"))

app = Flask(__name__)
inicio = datetime.now()
hoje = date.today()

# o estoque aqui ja e o atual (as vendas abaixo ja foram descontadas, como num ERP de verdade)
PRODUTOS = [
    {"codigo_barras": "7899000000011", "nome": "Arroz Branco 5kg", "categoria": "Mercearia",
     "preco_custo": 18.50, "preco_venda": 27.90, "quantidade_estoque": 40, "unidade": "UN"},
    {"codigo_barras": "7899000000028", "nome": "Feijão Carioca 1kg", "categoria": "Mercearia",
     "preco_custo": 5.20, "preco_venda": 8.49, "quantidade_estoque": 6, "unidade": "UN"},
    {"codigo_barras": "7899000000035", "nome": "Café Torrado 500g", "categoria": "Mercearia",
     "preco_custo": 11.00, "preco_venda": 17.90, "quantidade_estoque": 25, "unidade": "UN"},
    {"codigo_barras": "7899000000042", "nome": "Queijo Mussarela (kg)", "categoria": "Laticínios",
     "preco_custo": 32.00, "preco_venda": 49.90, "quantidade_estoque": 8, "unidade": "KG",
     "data_validade": (hoje + timedelta(days=12)).isoformat()},
    {"codigo_barras": "7899000000059", "nome": "Refrigerante Cola 2L", "categoria": "Bebidas",
     "preco_custo": 6.10, "preco_venda": 9.99, "quantidade_estoque": 60, "unidade": "UN"},
]
for p in PRODUTOS:
    p["atualizado_em"] = inicio

# vendas dos ultimos 20 dias (pra previsao de demanda ter historico)
VENDAS = []
for dias_atras in range(1, 21):
    dia = hoje - timedelta(days=dias_atras)
    for i, p in enumerate(PRODUTOS):
        quantidade = (dias_atras + i) % 4  # varia um pouco de dia pra dia; 0 = nao vendeu
        if quantidade:
            VENDAS.append({
                "id_externo": f"SIM-{dia:%Y%m%d}-{i + 1}",
                "codigo_barras": p["codigo_barras"],
                "quantidade": quantidade,
                "data_venda": dia.isoformat(),
                "registrada_em": inicio,
            })


def autorizado():
    return request.headers.get("Authorization", "") == "Bearer " + CHAVE


def ler_desde():
    texto = request.args.get("desde")
    if not texto:
        return None
    return datetime.fromisoformat(texto)


def sem_campos_internos(item, *campos):
    return {k: v for k, v in item.items() if k not in campos}


@app.before_request
def conferir_chave():
    if not autorizado():
        return jsonify({"erro": "chave da API inválida"}), 401
    return None


@app.get("/status")
def status():
    return jsonify({"status": "ok", "erp": "ERP simulado do NextStock", "produtos": len(PRODUTOS), "vendas": len(VENDAS)})


@app.get("/produtos")
def produtos():
    desde = ler_desde()
    lista = [p for p in PRODUTOS if desde is None or p["atualizado_em"] > desde]
    return jsonify([sem_campos_internos(p, "atualizado_em") for p in lista])


@app.get("/vendas")
def vendas():
    desde = ler_desde()
    lista = [v for v in VENDAS if desde is None or v["registrada_em"] > desde]
    return jsonify([sem_campos_internos(v, "registrada_em") for v in lista])


@app.post("/simular/venda")
def simular_venda():
    dados = request.get_json(silent=True) or {}
    codigo = dados.get("codigo_barras") or PRODUTOS[0]["codigo_barras"]
    quantidade = int(dados.get("quantidade") or 1)
    produto = next((p for p in PRODUTOS if p["codigo_barras"] == codigo), None)
    if not produto:
        return jsonify({"erro": "produto não existe no ERP simulado"}), 404
    agora = datetime.now()
    produto["quantidade_estoque"] = max(produto["quantidade_estoque"] - quantidade, 0)
    produto["atualizado_em"] = agora
    venda = {
        "id_externo": f"SIM-NOVA-{len(VENDAS) + 1}",
        "codigo_barras": codigo,
        "quantidade": quantidade,
        "data_venda": agora.date().isoformat(),
        "registrada_em": agora,
    }
    VENDAS.append(venda)
    return jsonify(sem_campos_internos(venda, "registrada_em")), 201


if __name__ == "__main__":
    print(f"ERP simulado em http://127.0.0.1:{PORTA}  (chave: {CHAVE})")
    app.run(port=PORTA)
