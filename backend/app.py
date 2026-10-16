import os
from flask import Flask, jsonify
from flask_cors import CORS
from dotenv import load_dotenv

from models.database import db
from models.venda_model import Venda
from models.evento_model import Evento
from models.clima_model import ClimaDia
from models.empresa_model import Empresa
from models.usuario_model import Usuario
from models.configuracao_erp_model import ConfiguracaoErp
from models.sincronizacao_erp_model import SincronizacaoErp
from models.erp_venda_importada_model import ErpVendaImportada
from models.lote_model import Lote
from models.movimentacao_estoque_model import MovimentacaoEstoque
from models.perda_model import Perda
from services.estoque_lote_service import criar_lotes_iniciais, preencher_historico
from controllers.categoria_controller import cat_bp
from controllers.produto_controller import prod_bp
from controllers.venda_controller import venda_bp
from controllers.evento_controller import evento_bp
from controllers.previsao_controller import previsao_bp
from controllers.clima_controller import clima_bp
from controllers.compra_controller import compra_bp
from controllers.reposicao_controller import reposicao_bp
from controllers.erp_controller import erp_bp
from controllers.importar_controller import importar_bp
from controllers.painel_controller import painel_bp
from controllers.recomendacao_controller import recomendacao_bp
from controllers.relatorio_controller import relatorio_bp
from controllers.assistente_controller import assistente_bp
from controllers.empresa_controller import empresa_bp
from controllers.usuario_controller import usuario_bp
from controllers.auth_controller import auth_bp, exigir_login
from controllers.lote_controller import lote_bp
from controllers.movimentacao_controller import movimentacao_bp
from controllers.perda_controller import perda_bp

load_dotenv()

app = Flask(__name__)
CORS(app, expose_headers=["Content-Disposition"])  # libera o front acessar a api

# url do banco vem do .env
app.config["SQLALCHEMY_DATABASE_URI"] = os.getenv(
    "DATABASE_URL",
    "mysql+pymysql://root:@localhost:3306/nextstock?charset=utf8mb4",
)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db.init_app(app)

# toda rota exige login, menos as publicas (ver controllers/auth_controller.py)
app.before_request(exigir_login)

app.register_blueprint(cat_bp)
app.register_blueprint(prod_bp)
app.register_blueprint(venda_bp)
app.register_blueprint(evento_bp)
app.register_blueprint(previsao_bp)
app.register_blueprint(clima_bp)
app.register_blueprint(compra_bp)
app.register_blueprint(reposicao_bp)
app.register_blueprint(erp_bp)
app.register_blueprint(importar_bp)
app.register_blueprint(painel_bp)
app.register_blueprint(recomendacao_bp)
app.register_blueprint(relatorio_bp)
app.register_blueprint(assistente_bp)
app.register_blueprint(empresa_bp)
app.register_blueprint(usuario_bp)
app.register_blueprint(auth_bp)
app.register_blueprint(lote_bp)
app.register_blueprint(movimentacao_bp)
app.register_blueprint(perda_bp)


@app.get("/")
def home():
    return jsonify({"msg": "API do NextStock rodando"})


# cria as tabelas se nao existir
with app.app_context():
    db.create_all()
    # historico de movimentacoes: registra o que ja existia antes dele (so na primeira vez)
    registros_antigos = preencher_historico()
    if registros_antigos:
        print(f"movimentacoes: {registros_antigos} registro(s) do historico antigo")
    # produto antigo com estoque e sem lote ganha o "estoque inicial" (so na primeira vez)
    lotes_criados = criar_lotes_iniciais()
    if lotes_criados:
        print(f"lotes: {lotes_criados} produto(s) ganharam o lote de estoque inicial")


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
