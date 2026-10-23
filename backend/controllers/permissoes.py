from functools import wraps

from flask import g, jsonify
from services.verificar_permissao_service import VerificarPermissaoService


# marca uma rota como so de administrador. o login ja foi conferido antes (exigir_login no app.py),
# entao aqui so falta olhar o perfil de quem esta logado.
# o @wraps mantem o nome da funcao: sem ele o Flask acha que todas as rotas protegidas sao a mesma.
def exigir_admin(funcao):
    @wraps(funcao)
    def protegida(*args, **kwargs):
        usuario = getattr(g, "usuario", None)
        if not VerificarPermissaoService().executar(usuario):
            return jsonify({"erro": "sem permissão para esta ação"}), 403
        return funcao(*args, **kwargs)

    return protegida
