from models.empresa_model import Empresa


# o sistema so esta pronto depois que a empresa (e o primeiro admin) foram cadastrados
class VerificarSetupService:

    def executar(self):
        return {"configurado": Empresa.buscar_unica() is not None}
