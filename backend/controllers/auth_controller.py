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
