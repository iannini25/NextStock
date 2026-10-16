from datetime import datetime

from .database import db


# o sistema atende uma empresa so (a da loja); ela e cadastrada na configuracao inicial
class Empresa(db.Model):
    __tablename__ = "empresa"

    id_empresa = db.Column(db.Integer, primary_key=True)
    nome = db.Column(db.String(150), nullable=False)
    nome_fantasia = db.Column(db.String(150))
    cnpj = db.Column(db.String(14), unique=True)
    email = db.Column(db.String(150))
    telefone = db.Column(db.String(20))
    criado_em = db.Column(db.DateTime, default=datetime.now)

    def salvar(self):
        db.session.add(self)
        db.session.commit()

    def atualizar(self, nome, nome_fantasia, cnpj, email, telefone):
        self.nome = nome
        self.nome_fantasia = nome_fantasia
        self.cnpj = cnpj
        self.email = email
        self.telefone = telefone
        db.session.commit()

    @staticmethod
    def buscar_unica():
        return Empresa.query.order_by(Empresa.id_empresa).first()

    def virar_dict(self):
        return {
            "id_empresa": self.id_empresa,
            "nome": self.nome,
            "nome_fantasia": self.nome_fantasia,
            "cnpj": self.cnpj,
            "email": self.email,
            "telefone": self.telefone,
        }
