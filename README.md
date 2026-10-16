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
proxy e o app. Cada um roda num terminal. Pra testar a integração com ERP sem ter um ERP de verdade,
tem também um ERP simulado opcional (seção 4), e pra testar o monitoramento de temperatura, um
sensor simulado (seção 5).

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

### 4. ERP simulado (opcional, pra testar a integração com ERP)

O `tools/erp_simulado/erp_simulado.py` é um ERP de mentira, feito em Flask, que responde do mesmo
jeito que o NextStock espera de um ERP de verdade. Ele já vem com **5 produtos** (arroz, feijão,
café, queijo e refrigerante) e **20 dias de vendas**, então dá pra testar o botão "Sincronizar
agora" do começo ao fim. Ele serve só pra desenvolvimento e teste.

**Antes, uma vez só: a chave de criptografia no `.env`**

A chave da API do ERP fica salva criptografada no banco. Pra isso, o `backend/.env` precisa da
`ERP_CHAVE_CRIPTOGRAFIA`, um texto aleatório de pelo menos 32 caracteres, diferente da `SECRET_KEY`.
Gere um com:

```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

Cole o resultado no `backend/.env`:

```
ERP_CHAVE_CRIPTOGRAFIA=<o texto gerado>
```

Depois **reinicie a API**, porque ela só lê o `.env` quando sobe. Guarde essa chave: se ela mudar,
a chave do ERP salva antes precisa ser cadastrada de novo.

**Subir o ERP simulado**

Com a API e o proxy rodando, em outro terminal, **na raiz do projeto**:

```bash
python tools/erp_simulado/erp_simulado.py
```

Ele sobe em `http://127.0.0.1:5001` e mostra a chave dele no terminal. Não precisa instalar nada
além do que o backend já usa.

**Configurar no app** (entre com um usuário **administrador**)

1. Abra **Integração ERP** no menu.
2. Preencha:
   - **URL da API do ERP:** `http://127.0.0.1:5001`
   - **Chave da API:** `chave-do-erp-simulado-123`
3. Clique em **Salvar** e depois em **Testar conexão**. Deve aparecer "Conexão com o ERP funcionando".
4. Clique em **Sincronizar agora**. Os 5 produtos e as vendas entram no NextStock, e o resultado
   aparece no **Histórico**, logo abaixo.

**O que dá pra testar com ele**

| Teste | Como fazer | O que deve acontecer |
|---|---|---|
| Chave errada | Salvar outra chave e testar a conexão | "o ERP recusou a chave da API" |
| Sincronizar de novo | Clicar em "Sincronizar agora" mais uma vez | 0 vendas novas (nada duplica) |
| Venda nova no ERP | Rodar o comando abaixo e sincronizar | Entra só 1 venda e o estoque do arroz cai |
| ERP fora do ar | Fechar o simulado (Ctrl+C) e sincronizar | Erro "Ele está no ar?", registrado no histórico como "Falhou" |
| Integração desligada | Desligar "Integração ativa", salvar e sincronizar | "a integração com o ERP está desligada" |

Para registrar uma venda nova no ERP simulado (PowerShell):

```powershell
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:5001/simular/venda -Headers @{Authorization='Bearer chave-do-erp-simulado-123'}
```

No Linux/Mac:

```bash
curl -X POST http://127.0.0.1:5001/simular/venda -H "Authorization: Bearer chave-do-erp-simulado-123"
```

Dá pra escolher o produto e a quantidade mandando um JSON, por exemplo
`{"codigo_barras": "7899000000028", "quantidade": 3}`.

> **Bom saber**
> - Os dados do simulado ficam só na memória: fechou e abriu de novo, ele volta ao estado
>   inicial. O que já foi sincronizado continua no banco do NextStock.
> - As vendas sincronizadas entram no banco de verdade e passam a contar no painel, nos
>   relatórios e na previsão.
> - Dá pra mudar a chave e a porta do simulado com as variáveis `ERP_SIMULADO_CHAVE` e
>   `ERP_SIMULADO_PORTA`.
> - Pra ligar um ERP de verdade, é só ele seguir o mesmo formato (rotas `/status`, `/produtos` e
>   `/vendas`, autenticação `Authorization: Bearer <chave>`, descrito no começo do
>   `erp_simulado.py`) ou criar um conector novo em `backend/services/erp/`.

### 5. Sensor de temperatura simulado (opcional, pra testar o monitoramento do armazenamento)

As leituras de temperatura podem ser lançadas na tela (**Armazenamento** → abrir o local →
"Registrar leitura") ou chegar sozinhas de um dispositivo. O `tools/simular_sensor.py` faz o papel
desse dispositivo: de tempos em tempos manda uma leitura e, de vez em quando, um pico fora da faixa
pra disparar o alerta. Não precisa instalar nada.

**Antes, uma vez só: a chave do sensor no `.env`**

O sensor não faz login: ele manda uma chave no header `X-Sensor-Key`, e essa chave só serve pra
registrar leitura. Gere uma com:

```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

Cole no `backend/.env` e **reinicie a API**:

```
SENSOR_API_KEY=<o texto gerado>
```

**Rodar o simulador**

1. No app, entre como **administrador**, abra **Armazenamento** e crie o local (ex.: "Geladeira
   laticínios", refrigerado, de 0 a 5 °C).
2. Abra o local e veja o número dele no cartão de cima (`Local #1`).
3. Com a API e o proxy rodando, em outro terminal, **na raiz do projeto**:

```bash
python tools/simular_sensor.py --local 1 --min 0 --max 5
```

Ele lê a `SENSOR_API_KEY` do `backend/.env` sozinho e manda uma leitura a cada 5 segundos. A cada 6
leituras vem um pico acima do máximo. Pare com Ctrl+C.

Opções úteis: `--intervalo 10` (segundos entre leituras), `--pico-cada 3` (0 = nunca), `--vezes 5`
(para depois de 5 leituras) e `--chave ...` (se não quiser ler do `.env`).

**O que dá pra testar com ele**

| Teste | O que deve acontecer |
|---|---|
| Leitura dentro da faixa | O local fica "OK" na tela Armazenamento |
| Pico fora da faixa | O local fica "Fora da faixa", aparece o aviso em Alertas e o selo do menu aumenta |
| Chave errada (`--chave errada`) | "chave do sensor inválida" e o simulador para |
| Sem `SENSOR_API_KEY` no `.env` | "sensor não configurado: defina SENSOR_API_KEY no .env e reinicie a API" |
| Parar o simulador por mais de 12 h | O local vira "Sem leitura" |

> Um local sem nenhuma leitura também aparece como "Sem leitura": registre a primeira leitura
> (na tela ou com o simulador) para ele ficar "OK".
