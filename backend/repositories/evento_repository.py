from models.evento_model import Evento


class EventoRepository:

    def listar_no_periodo(self, inicio, fim):
        return (
            Evento.query
            .filter(Evento.data_inicio <= fim)
            .filter(Evento.data_fim >= inicio)
            .order_by(Evento.data_inicio.asc())
            .all()
        )
