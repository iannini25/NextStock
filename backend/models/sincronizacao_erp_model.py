import json
from datetime import datetime

from .database import db


# historico de cada vez que o NextStock buscou dados no ERP
class SincronizacaoErp(db.Model):
    __tablename__ = "sincronizacao_erp"

    id_sincronizacao = db.Column(db.Integer, primary_key=True)
    iniciado_em = db.Column(db.DateTime, nullable=False, default=datetime.now)
    finalizado_em = db.Column(db.DateTime)
    status = db.Column(db.String(20), nullable=False, default="em_andamento")  # em_andamento | sucesso | parcial | erro
    produtos_criados = db.Column(db.Integer, nullable=False, default=0)
    produtos_atualizados = db.Column(db.Integer, nullable=False, default=0)
    vendas_importadas = db.Column(db.Integer, nullable=False, default=0)
    vendas_ja_importadas = db.Column(db.Integer, nullable=False, default=0)
    erros = db.Column(db.Text)  # lista em JSON
    id_usuario = db.Column(db.Integer, db.ForeignKey("usuario.id_usuario"))

    usuario = db.relationship("Usuario")

    def salvar(self):
        db.session.add(self)
        db.session.commit()

    def lista_erros(self):
        return json.loads(self.erros) if self.erros else []

    @staticmethod
    def listar_recentes(limite):
        from repositories.sincronizacao_erp_repository import SincronizacaoErpRepository
        return SincronizacaoErpRepository().listar_recentes(limite)

    # a ultima que deu certo sem nenhum erro: a proxima busca so o que mudou depois dela
    @staticmethod
    def ultima_com_sucesso():
        from repositories.sincronizacao_erp_repository import SincronizacaoErpRepository
        return SincronizacaoErpRepository().ultima_com_sucesso()

    def virar_dict(self):
        return {
            "id_sincronizacao": self.id_sincronizacao,
            "iniciado_em": self.iniciado_em.isoformat(timespec="seconds") if self.iniciado_em else None,
            "finalizado_em": self.finalizado_em.isoformat(timespec="seconds") if self.finalizado_em else None,
            "status": self.status,
            "produtos_criados": self.produtos_criados,
            "produtos_atualizados": self.produtos_atualizados,
            "vendas_importadas": self.vendas_importadas,
            "vendas_ja_importadas": self.vendas_ja_importadas,
            "erros": self.lista_erros(),
            "usuario": self.usuario.nome if self.usuario else None,
        }
