import requests
from flask import Flask, request, Response
from flask_cors import CORS

app = Flask(__name__)
CORS(app, expose_headers=["Content-Disposition"])  # deixa o app (flutter web) falar com o proxy

# a api de verdade fica aqui, escondida. so o proxy conversa com ela.
API = "http://127.0.0.1:5000"


# cabecalhos que o proxy nao deve reenviar (multipart/download quebram se forem copiados)
_IGNORAR = {"host", "content-length", "connection", "transfer-encoding"}


# pega qualquer rota e repassa pra api
@app.route("/", defaults={"caminho": ""}, methods=["GET", "POST", "PUT", "DELETE"])
@app.route("/<path:caminho>", methods=["GET", "POST", "PUT", "DELETE"])
def repassar(caminho):
    print("proxy ->", request.method, "/" + caminho)
    resp = requests.request(
        method=request.method,
        url=f"{API}/{caminho}",
        params=request.args,
        data=request.get_data(),
        headers={k: v for k, v in request.headers if k.lower() not in _IGNORAR},
    )
    # devolve a resposta do jeito que a api mandou (inclui download de modelo)
    saida = {}
    if resp.headers.get("Content-Type"):
        saida["Content-Type"] = resp.headers["Content-Type"]
    if resp.headers.get("Content-Disposition"):
        saida["Content-Disposition"] = resp.headers["Content-Disposition"]
    return Response(resp.content, status=resp.status_code, headers=saida)


if __name__ == "__main__":
    app.run(port=8000)
