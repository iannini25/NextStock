# NextStock

## Sobre o Projeto

O NextStock é uma plataforma de inteligência preditiva para gestão de estoque no varejo de
perecíveis. A ideia é usar dados de vendas, estoque, sazonalidade, clima e eventos locais para
prever a demanda e ajudar o lojista a comprar, repor e promover melhor, reduzindo desperdício e
evitando falta de produto em mercados, padarias, açougues e hortifrutis.

Esta entrega é o **CRUD das principais Models**: cadastro/listagem/edição/exclusão feitos por uma
API em Flask + SQLAlchemy com banco MySQL, e um **app em Flutter** que consome essa API.

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
**Frontend:** Flutter (Dart), usando o pacote `http` pra falar com a API

## Arquitetura

Backend em camadas (como pede a atividade):

```
App Flutter  ->  Proxy  ->  Controller  ->  Service  ->  Model (ORM)  ->  MySQL
```

* **Model** (`models/`): representa a tabela, herda de `db.Model` e tem os métodos de salvar,
  editar, apagar, pegar todos e pegar por id.
* **Service** (`services/`): um arquivo por caso de uso (criar, listar, buscar, atualizar,
  deletar). É onde ficam as validações.
* **Controller** (`controllers/`): as rotas da API (Blueprint do Flask), recebem a requisição,
  chamam o service e devolvem JSON.
* **Proxy** (`proxy/`): um Flask pequeno que fica na frente da API. O app só fala com o proxy, e
  o proxy repassa tudo pra API. Assim a API não fica exposta direto.

No app Flutter a organização é simples: `models/` (as classes), `services/api_service.dart` (as
chamadas http) e `screens/` (as telas). Nada de gerenciador de estado, só `StatefulWidget` +
`setState`.

## Models implementadas

* **Categoria** — `id_categoria`, `nome`, `descricao`
* **Produto** — `id_produto`, `id_categoria` (FK pra Categoria), `nome`, `codigo_barras`,
  `preco_custo`, `preco_venda`, `quantidade_estoque`, `unidade`, `data_validade`

Cada produto pode pertencer a uma categoria (relacionamento por chave estrangeira).

## Funcionalidades

Para as duas Models tem o CRUD completo, tanto na API quanto no app:

* Cadastrar
* Listar
* Buscar por id
* Editar
* Excluir (com confirmação)

Validações: nome e preço de venda obrigatórios, preço/quantidade não podem ser negativos, código
de barras não pode repetir e a categoria informada tem que existir. Os erros da API aparecem no app
num SnackBar vermelho.

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
├── backend/                        # a API (Flask) - NÃO muda
│   ├── app.py
│   ├── requirements.txt
│   ├── .env.example
│   ├── database/create_database.sql
│   ├── models/                     # Categoria e Produto (herdam de db.Model)
│   ├── services/                   # um arquivo por caso de uso
│   └── controllers/                # as rotas da API
├── proxy/                          # proxy simples na frente da API
│   ├── proxy.py
│   └── requirements.txt
└── frontend/                       # o app Flutter (novo)
    ├── pubspec.yaml                # dependencias (tem o http)
    └── lib/
        ├── main.dart               # entrada do app, tema e navegacao
        ├── models/
        │   ├── produto.dart        # classe Produto (fromJson/toJson)
        │   └── categoria.dart
        ├── services/
        │   └── api_service.dart    # todas as chamadas http + erros
        └── screens/
            ├── produtos_screen.dart
            ├── produto_form.dart
            ├── categorias_screen.dart
            └── categoria_form.dart
```

## Como rodar

Precisa de **Python 3.10+**, **MySQL** e o **Flutter SDK** instalados. São 3 partes: a API, o
proxy e o app. Cada um roda num terminal.

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

A API fica em `http://127.0.0.1:5000`.

> Se não quiser instalar MySQL só pra testar, dá pra usar SQLite: no `.env` deixe
> `DATABASE_URL=sqlite:///nextstock.db`. A aplicação cria as tabelas sozinha ao subir.

> **Deixar a API escondida:** o ideal é a API só aceitar conexão local, pra ninguém acessar ela
> direto (só o proxy). Pra isso, em `app.py` troque `host="0.0.0.0"` por `host="127.0.0.1"`. Aí
> só o proxy fica acessível de fora.

### 2. Proxy

Com a API rodando, em outro terminal:

```bash
cd proxy
pip install -r requirements.txt
python proxy.py
```

O proxy sobe em `http://127.0.0.1:8000` e repassa tudo pra API na 5000.

### 3. Frontend (o app Flutter)

Deixe a API e o proxy rodando e, em outro terminal:

```bash
cd frontend
flutter pub get
flutter run
```

Escolha o dispositivo (Chrome, Windows, Android...). Pra rodar no Chrome direto:
`flutter run -d chrome`.

> **Endereço:** no arquivo `frontend/lib/services/api_service.dart` tem a constante `baseUrl`, que
> aponta pro **proxy**. Deixe `http://127.0.0.1:8000` pra web e desktop. Se for rodar no **emulador
> Android**, troque pra `http://10.0.2.2:8000` (é assim que o emulador enxerga o localhost do PC).
