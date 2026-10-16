from models.empresa_model import Empresa


class BuscarEmpresaService:

    def executar(self):
        empresa = Empresa.buscar_unica()
        if not empresa:
            return None
        return empresa.virar_dict()
