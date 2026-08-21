from models.evento_model import Evento


class ListarEventosService:

    def executar(self):
        return [e.virar_dict() for e in Evento.listar_todos()]
