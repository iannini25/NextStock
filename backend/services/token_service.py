import os
import secrets

from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer

# sem SECRET_KEY no .env (ou com o texto de exemplo do .env.example) a api ainda sobe,
# mas com uma chave sorteada: todo mundo precisa entrar de novo sempre que a api reinicia
_CHAVE_RESERVA = secrets.token_hex(32)
_CHAVE_DE_EXEMPLO = "troque_por_um_texto_aleatorio"


# token de login assinado (nao da pra falsificar sem a SECRET_KEY). vale 12 horas.
class TokenService:

    VALIDADE_SEGUNDOS = 12 * 60 * 60

    def __init__(self):
        chave = os.getenv("SECRET_KEY")
        if not chave or chave == _CHAVE_DE_EXEMPLO:
            chave = _CHAVE_RESERVA
        self.serializer = URLSafeTimedSerializer(chave, salt="nextstock-login")

    def gerar(self, usuario):
        return self.serializer.dumps({"id": usuario.id_usuario})

    # devolve o id do usuario, ou None se o token for invalido ou estiver vencido
    def ler(self, token):
        try:
            dados = self.serializer.loads(token, max_age=self.VALIDADE_SEGUNDOS)
        except (SignatureExpired, BadSignature):
            return None
        if not isinstance(dados, dict):
            return None
        return dados.get("id")
