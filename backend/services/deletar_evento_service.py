from models.evento_model import Evento


class DeletarEventoService:

    def executar(self, id):
        evento = Evento.buscar_por_id(id)
        if not evento:
            return False
        evento.deletar()
        return True
