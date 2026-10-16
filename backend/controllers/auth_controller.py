import hmac
import os
import re

from flask import Blueprint, g, request, jsonify

from models.empresa_model import Empresa
from models.usuario_model import Usuario
from services.login_service import LoginService
from services.token_service import TokenService

auth_bp = Blueprint("auth", __name__)

# rotas que funcionam sem login
ROTAS_PUBLICAS = {
    ("GET", "/"),
    ("POST", "/auth/login"),
    ("GET", "/setup/status"),
}

# a unica rota que um dispositivo (sensor de temperatura) usa, com o header X-Sensor-Key no lugar do login
ROTA_DO_SENSOR = re.compile(r"^/locais-armazenamento/\d+/leituras$")


# sensor mandando leitura: so passa com a chave certa (SENSOR_API_KEY no .env).
# devolve None se liberou, ou a resposta de erro. a chave nunca vai pro log nem pra resposta
def conferir_sensor(chave):
    esperada = os.getenv("SENSOR_API_KEY", "")
    if not esperada:
        return jsonify({"erro": "sensor não configurado: defina SENSOR_API_KEY no .env e reinicie a API"}), 401
    if not hmac.compare_digest(chave.encode(), esperada.encode()):
        return jsonify({"erro": "chave do sensor inválida"}), 401
    g.sensor = True
    return None


# roda antes de toda requisicao (registrado no app.py): sem token valido, responde 401.
# assim nenhuma rota fica sem protecao, nem as que ainda vao ser criadas.
def exigir_login():
    if request.method == "OPTIONS":  # preflight do CORS (Flutter Web) nao leva token
        return None
    if (request.method, request.path) in ROTAS_PUBLICAS:
        return None
    # a configuracao inicial so e publica enquanto nao existe empresa
    if request.method == "POST" and request.path == "/setup" and not Empresa.buscar_unica():
        return None
    # dispositivo enviando leitura de temperatura (sem o header, segue o login normal)
    chave_sensor = request.headers.get("X-Sensor-Key")
    if chave_sensor is not None and request.method == "POST" and ROTA_DO_SENSOR.match(request.path):
        return conferir_sensor(chave_sensor)

    cabecalho = request.headers.get("Authorization", "")
    if not cabecalho.startswith("Bearer "):
        return jsonify({"erro": "faça login para continuar"}), 401

    id_usuario = TokenService().ler(cabecalho[len("Bearer "):].strip())
    usuario = Usuario.buscar_por_id(id_usuario) if id_usuario else None
    if not usuario or not usuario.ativo:
        return jsonify({"erro": "sua sessão expirou, entre de novo"}), 401

    g.usuario = usuario
    return None


class AuthController:

    @staticmethod
    def login():
        try:
            resultado = LoginService().executar(request.get_json(silent=True) or {})
            if not resultado:
                return jsonify({"erro": "e-mail ou senha inválidos"}), 401
            return jsonify(resultado)
        except ValueError as e:
            return jsonify({"erro": str(e)}), 400

    # quem esta logado (o app usa pra conferir o token salvo quando abre)
    @staticmethod
    def eu():
        return jsonify({"usuario": g.usuario.virar_dict(), "empresa": g.usuario.empresa.virar_dict()})


auth_bp.add_url_rule("/auth/login", view_func=AuthController.login, methods=["POST"])
auth_bp.add_url_rule("/auth/me", view_func=AuthController.eu, methods=["GET"])
