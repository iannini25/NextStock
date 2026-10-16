import base64
import hashlib
import os

from cryptography.fernet import Fernet, InvalidToken

COMO_GERAR = 'gere uma com: python -c "import secrets; print(secrets.token_hex(32))"'


# a API nao consegue criptografar porque falta (ou esta fraca) a chave no .env
class ChaveDeCriptografiaFaltando(Exception):
    pass


# criptografa segredos (ex.: chave da API do ERP) antes de ir pro banco.
# usa a ERP_CHAVE_CRIPTOGRAFIA do .env; sem ela da pra ver a configuracao, mas nao gravar chave nova.
class CriptoService:

    def __init__(self):
        segredo = (os.getenv("ERP_CHAVE_CRIPTOGRAFIA") or "").strip()
        if not segredo:
            raise ChaveDeCriptografiaFaltando(
                "configure a ERP_CHAVE_CRIPTOGRAFIA no .env da API e reinicie a API (" + COMO_GERAR + ")"
            )
        # texto curto ou repetitivo (ex.: 123456...) seria facil de adivinhar
        if len(segredo) < 32 or len(set(segredo)) < 12:
            raise ChaveDeCriptografiaFaltando(
                "a ERP_CHAVE_CRIPTOGRAFIA do .env da API é fraca: use um texto aleatório de pelo menos 32 caracteres ("
                + COMO_GERAR + ")"
            )
        # qualquer texto aleatorio serve: vira uma chave no formato que o Fernet exige
        chave = base64.urlsafe_b64encode(hashlib.sha256(segredo.encode()).digest())
        self.fernet = Fernet(chave)

    def criptografar(self, texto):
        return self.fernet.encrypt(texto.encode()).decode()

    # devolve None se o texto foi criptografado com outra chave (ex.: trocaram a chave do .env)
    def descriptografar(self, token):
        try:
            return self.fernet.decrypt(token.encode()).decode()
        except InvalidToken:
            return None
