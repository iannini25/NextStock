import os
from flask import Flask, jsonify
from flask_cors import CORS
from dotenv import load_dotenv

from models.database import db
from controllers.categoria_controller import cat_bp
from controllers.produto_controller import prod_bp

load_dotenv()

app = Flask(__name__)
CORS(app)  # libera o front acessar a api

# url do banco vem do .env
app.config["SQLALCHEMY_DATABASE_URI"] = os.getenv(
    "DATABASE_URL",
    "mysql+pymysql://root:@localhost:3306/nextstock?charset=utf8mb4",
)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db.init_app(app)

app.register_blueprint(cat_bp)
app.register_blueprint(prod_bp)


@app.get("/")
def home():
    return jsonify({"msg": "API do NextStock rodando"})


# cria as tabelas se nao existir
with app.app_context():
    db.create_all()


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
