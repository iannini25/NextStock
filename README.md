# NextStock

## Sobre o Projeto

O NextStock é uma plataforma de inteligência preditiva para gestão de estoque no varejo de
perecíveis. A ideia é usar dados de vendas, estoque, sazonalidade, clima e eventos locais para
prever a demanda e ajudar o lojista a comprar, repor e promover melhor, reduzindo desperdício e
evitando falta de produto em mercados, padarias, açougues e hortifrutis.

Esta entrega são **10 funcionalidades completas de ponta a ponta**: o CRUD de Produto e Categoria
mais dois alertas (produto vencendo e produto em risco de faltar), feitos por uma API em Flask +
SQLAlchemy com banco MySQL e um **app em Flutter** que consome essa API.

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
App Flutter  ->  Proxy  ->  Controller  ->  Service  ->  Model / Repository  ->  MySQL
```

* **Model** (`models/`): representa a tabela, herda de `db.Model` e tem os métodos `salvar()`,
  `atualizar()`, `deletar()`, `listar_todos()` e `buscar_por_id()`.
* **Service** (`services/`): uma classe por caso de uso (`CriarProdutoService`,
  `ListarProdutosVencendoService`...), cada uma com um método `executar()`. É onde ficam as
  validações.
* **Repository** (`repositories/`): só pras consultas que fogem do CRUD, tipo filtro por data de
  validade e comparação entre colunas. O service não monta query, ele pede pro repository.
* **Controller** (`controllers/`): uma classe por recurso (`ProdutoController`,
  `CategoriaController`). Recebe a requisição, chama o service e devolve JSON. As rotas do
  Blueprint ficam registradas no fim do arquivo apontando pros métodos da classe.
* **Proxy** (`proxy/`): um Flask pequeno que fica na frente da API. O app só fala com o proxy, e
  o proxy repassa tudo pra API. Assim a API não fica exposta direto.

No app Flutter a organização é simples: `models/` (as classes), `services/api_service.dart` (as
chamadas http) e `screens/` (as telas). Nada de gerenciador de estado, só `StatefulWidget` +
`setState`.

## Models implementadas

* **Categoria** — `id_categoria`, `nome`, `descricao`
* **Produto** — `id_produto`, `id_categoria` (FK pra Categoria), `nome`, `codigo_barras`,
  `preco_custo`, `preco_venda`, `quantidade_estoque`, `estoque_minimo`, `unidade`, `data_validade`

Cada produto pode pertencer a uma categoria (relacionamento por chave estrangeira).

## Funcionalidades Implementadas

As 10 funcionalidades estao completas de ponta a ponta
(tela Flutter -> proxy -> API Flask -> Controller -> Service -> Model/Repository -> banco):

1. Cadastrar categoria
2. Listar categorias
3. Atualizar categoria
4. Excluir categoria
5. Cadastrar produto
6. Listar produtos
7. Atualizar produto
8. Excluir produto
9. Listar produtos proximos do vencimento (alerta de validade, com filtro de dias)
10. Listar produtos em risco de ruptura (estoque atual <= estoque minimo)

As duas ultimas usam o `ProdutoRepository`, porque sao consultas com filtro e nao CRUD simples.
Elas atendem os requisitos RF03 (alerta de vencimento) e RF06 (risco de ruptura) do projeto.

Validacoes: nome e preco de venda obrigatorios, preco/quantidade nao podem ser negativos, codigo
de barras nao pode repetir e a categoria informada tem que existir. Os erros da API aparecem no app
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

### Alertas (essas duas passam pelo Repository)
| Método | Rota                        | O que faz                                |
|--------|-----------------------------|------------------------------------------|
| GET    | `/produtos/vencendo?dias=7` | produtos que vencem nos próximos X dias  |
| GET    | `/produtos/risco-ruptura`   | produtos com estoque <= estoque mínimo   |

Exemplo de JSON pra criar um produto:

```json
{
  "nome": "Iogurte Natural 170g",
  "id_categoria": 2,
  "codigo_barras": "7891234567890",
  "preco_custo": "1.80",
  "preco_venda": "3.50",
  "quantidade_estoque": 60,
  "estoque_minimo": 20,
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
│   ├── services/                   # uma classe por caso de uso
│   ├── repositories/               # consultas especiais (vencimento, ruptura)
│   └── controllers/                # classes com as rotas da API
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
            ├── alertas_screen.dart
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
