# NextStock

## Sobre o Projeto

O NextStock é uma plataforma de inteligência preditiva para gestão de estoque no varejo de
perecíveis. A ideia é usar dados de vendas, estoque, sazonalidade, clima e eventos locais para
prever a demanda e ajudar o lojista a comprar, repor e promover melhor, reduzindo desperdício e
evitando falta de produto em mercados, padarias, açougues e hortifrutis.

Esta entrega é a parte de **CRUD da API**: implementamos o cadastro/listagem/edição/exclusão das
principais Models do sistema, com backend em Flask + SQLAlchemy, banco MySQL e uma tela simples em
HTML/CSS/JavaScript consumindo a API.

## Equipe

* Bernardo Iannini
* José Augusto
* Manuella Zanola
* Matheus Freitas Martins
* Renan
* Gabriel Abi-Acl

## Stack

**Backend:** Python + Flask + SQLAlchemy (ORM)
**Banco:** MySQL (driver PyMySQL)
**Frontend:** HTML + CSS + JavaScript puro

> A visão do produto usa Flutter/IA, mas para esta atividade de CRUD o frontend é web simples
> (HTML/CSS/JS) consumindo a API do Flask.

## Arquitetura

Seguimos a arquitetura em camadas pedida na atividade:

```
Tela (HTML/JS)  ->  Controller  ->  Service  ->  Model (ORM)  ->  MySQL
```

* **Model** (`models/`): representa a tabela, herda de `db.Model` e tem os métodos de salvar,
  editar, apagar, pegar todos e pegar por id.
* **Service** (`services/`): um arquivo por caso de uso (criar, listar, buscar, atualizar,
  deletar). É onde ficam as validações.
* **Controller** (`controllers/`): as rotas da API (Blueprint do Flask), recebem a requisição,
  chamam o service e devolvem JSON.

## Models implementadas

* **Categoria** — `id_categoria`, `nome`, `descricao`
* **Produto** — `id_produto`, `id_categoria` (FK pra Categoria), `nome`, `codigo_barras`,
  `preco_custo`, `preco_venda`, `quantidade_estoque`, `unidade`, `data_validade`

Cada produto pode pertencer a uma categoria (relacionamento por chave estrangeira).

## Funcionalidades

Para as duas Models tem o CRUD completo, tanto na API quanto na tela:

* Cadastrar
* Listar
* Buscar por id
* Editar
* Excluir

Validações: nome e preço de venda obrigatórios, preço/quantidade não podem ser negativos, código
de barras não pode repetir e a categoria informada tem que existir.

## Rotas da API

### Categorias
| Método | Rota               | O que faz              |
|--------|--------------------|------------------------|
| GET    | `/categorias`      | lista todas            |
| GET    | `/categorias/<id>` | busca uma pelo id      |
| POST   | `/categorias`      | cria                   |
| PUT    | `/categorias/<id>` | edita                  |
| DELETE | `/categorias/<id>` | apaga                  |

### Produtos
| Método | Rota              | O que faz              |
|--------|-------------------|------------------------|
| GET    | `/produtos`       | lista todos            |
| GET    | `/produtos/<id>`  | busca um pelo id       |
| POST   | `/produtos`       | cria                   |
| PUT    | `/produtos/<id>`  | edita                  |
| DELETE | `/produtos/<id>`  | apaga                  |

Exemplo de JSON pra criar um produto:

```json
{
  "nome": "Iogurte Natural 170g",
  "id_categoria": 2,
  "codigo_barras": "7891234567890",
  "preco_custo": "1.80",
  "preco_venda": "3.50",
  "quantidade_estoque": 60,
  "unidade": "UN",
  "data_validade": "2026-08-15"
}
```

## Estrutura de pastas

```
NextStock/
├── backend/
│   ├── app.py                     # sobe a api, conecta no banco e registra as rotas
│   ├── requirements.txt
│   ├── .env.example               # copie pra .env e ponha a senha do mysql
│   ├── database/
│   │   └── create_database.sql    # cria o banco no mysql + dados de exemplo
│   ├── models/
│   │   ├── database.py            # instancia do SQLAlchemy (db)
│   │   ├── categoria_model.py
│   │   └── produto_model.py
│   ├── services/                  # um arquivo por caso de uso
│   │   ├── utils.py               # conversoes (numero, inteiro, data)
│   │   ├── criar_categoria_service.py
│   │   ├── listar_categorias_service.py
│   │   ├── buscar_categoria_service.py
│   │   ├── atualizar_categoria_service.py
│   │   ├── deletar_categoria_service.py
│   │   ├── criar_produto_service.py
│   │   ├── listar_produtos_service.py
│   │   ├── buscar_produto_service.py
│   │   ├── atualizar_produto_service.py
│   │   └── deletar_produto_service.py
│   └── controllers/
│       ├── categoria_controller.py
│       └── produto_controller.py
└── frontend/
    ├── index.html                 # tela de produtos
    ├── categorias.html            # tela de categorias
    ├── css/style.css
    └── js/
        ├── api.js                 # funcao que fala com a api
        ├── produtos.js
        └── categorias.js
```

## Como rodar

Precisa de Python 3.10+ e MySQL instalado e rodando.

### 1. Backend (a API)

```bash
cd backend

# ambiente virtual
python -m venv venv
venv\Scripts\activate        # linux/mac: source venv/bin/activate

# instala as dependencias
pip install -r requirements.txt

# cria o banco no mysql (ja poe dados de exemplo)
mysql -u root -p < database/create_database.sql

# configura a conexao: copia o modelo e poe a senha do seu mysql no .env
copy .env.example .env       # linux/mac: cp .env.example .env

# sobe a api
python app.py
```

A API fica em `http://127.0.0.1:5000`. Abrir esse endereço mostra a mensagem "API do NextStock
rodando", sinal de que subiu.

> Se não quiser instalar MySQL só pra testar, dá pra usar SQLite: no `.env` deixe
> `DATABASE_URL=sqlite:///nextstock.db`. A aplicação cria as tabelas sozinha ao subir.

### 2. Frontend (a tela)

São arquivos estáticos, sobem separados da API. Jeito mais fácil:

```bash
cd frontend
python -m http.server 5500
```

Depois abre no navegador `http://127.0.0.1:5500`. Também dá pra abrir com a extensão Live Server do
VS Code. Se mudar a porta/endereço da API, ajuste a constante `URL` em `frontend/js/api.js`.
