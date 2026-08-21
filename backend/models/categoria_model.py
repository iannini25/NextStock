from .database import db


class Categoria(db.Model):
    __tablename__ = "categoria"

    id_categoria = db.Column(db.Integer, primary_key=True)
    nome = db.Column(db.String(60), nullable=False)
    descricao = db.Column(db.String(255))

    def salvar(self):
        db.session.add(self)
        db.session.commit()

    # muda nome e descricao
    def atualizar(self, nome, descricao):
        self.nome = nome
        self.descricao = descricao
        db.session.commit()

    def deletar(self):
        db.session.delete(self)
        db.session.commit()

    @staticmethod
    def listar_todos():
        return Categoria.query.all()

    @staticmethod
    def buscar_por_id(id):
        return Categoria.query.get(id)

    def virar_dict(self):
        return {
            "id_categoria": self.id_categoria,
            "nome": self.nome,
            "descricao": self.descricao,
        }
