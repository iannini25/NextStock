from datetime import datetime

from .database import db


# como falar com o ERP da empresa. a chave da API fica criptografada, nunca em texto puro.
class ConfiguracaoErp(db.Model):
    __tablename__ = "configuracao_erp"

    PROVEDORES = {"generico": "ERP genérico (API REST)"}

    id_configuracao = db.Column(db.Integer, primary_key=True)
    id_empresa = db.Column(db.Integer, db.ForeignKey("empresa.id_empresa"), unique=True, nullable=False)
    provedor = db.Column(db.String(30), nullable=False, default="generico")
    url_base = db.Column(db.String(255), nullable=False)
    chave_criptografada = db.Column(db.Text)
    ativo = db.Column(db.Boolean, nullable=False, default=True)
    atualizado_em = db.Column(db.DateTime, default=datetime.now)
    atualizado_por = db.Column(db.Integer, db.ForeignKey("usuario.id_usuario"))

    usuario = db.relationship("Usuario")

    def salvar(self):
        db.session.add(self)
        db.session.commit()

    @staticmethod
    def buscar_da_empresa(id_empresa):
        return ConfiguracaoErp.query.filter_by(id_empresa=id_empresa).first()
