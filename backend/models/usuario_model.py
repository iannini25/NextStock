from datetime import datetime

from werkzeug.security import check_password_hash, generate_password_hash

from .database import db


class Usuario(db.Model):
    __tablename__ = "usuario"

    PERFIS = ("admin", "usuario")

    id_usuario = db.Column(db.Integer, primary_key=True)
    id_empresa = db.Column(db.Integer, db.ForeignKey("empresa.id_empresa"), nullable=False)
    nome = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(150), unique=True, nullable=False)
    senha_hash = db.Column(db.String(255), nullable=False)
    perfil = db.Column(db.String(10), nullable=False, default="usuario")
    # usuario nao e apagado, so desativado (outras tabelas vao apontar pra ele)
    ativo = db.Column(db.Boolean, nullable=False, default=True)
    criado_em = db.Column(db.DateTime, default=datetime.now)

    empresa = db.relationship("Empresa")

    # a senha nunca e guardada, so o hash dela
    def definir_senha(self, senha):
        self.senha_hash = generate_password_hash(senha)

    def conferir_senha(self, senha):
        return check_password_hash(self.senha_hash, senha)

    def salvar(self):
        db.session.add(self)
        db.session.commit()

    def atualizar(self, nome, email, perfil, ativo):
        self.nome = nome
        self.email = email
        self.perfil = perfil
        self.ativo = ativo
        db.session.commit()

    def desativar(self):
        self.ativo = False
        db.session.commit()

    @staticmethod
    def listar_todos():
        return Usuario.query.order_by(Usuario.nome).all()

    @staticmethod
    def buscar_por_id(id):
        return db.session.get(Usuario, id)

    @staticmethod
    def buscar_por_email(email):
        return Usuario.query.filter_by(email=email).first()

    # senha_hash fica de fora de proposito
    def virar_dict(self):
        return {
            "id_usuario": self.id_usuario,
            "id_empresa": self.id_empresa,
            "nome": self.nome,
            "email": self.email,
            "perfil": self.perfil,
            "ativo": self.ativo,
        }
