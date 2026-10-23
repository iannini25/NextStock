# NextStock

Sistema de controle de estoque para mercados, padarias, acougues e hortifrutis, focado em
produtos pereciveis. Ele usa as vendas, a validade dos lotes, o clima e os eventos da cidade
para avisar o que esta vencendo, o que vai faltar e o que esta sobrando, reduzindo desperdicio.

Sao duas partes: uma API em Flask com banco MySQL e um aplicativo em Flutter que consome essa API.

## Equipe

* Bernardo Iannini
* Jose Augusto
* Manuella Zanola
* Matheus Freitas Martins
* Renan
* Gabriel Abi-Acl

## Stack

* **Frontend:** Flutter (Dart), usando o pacote `http` para chamar a API
* **Backend:** Python + Flask + SQLAlchemy (ORM)
* **Banco:** MySQL (driver PyMySQL)

## Arquitetura

O caminho de toda funcionalidade e sempre o mesmo:

```
Tela (Flutter) -> API Flask -> Controller -> Service -> Model / Repository -> MySQL
```

* **Model** (`backend/models/`): representa a tabela. Herda de `db.Model` e tem os metodos de
  persistencia (`salvar()`, `atualizar()`, `deletar()`, `listar_todos()`, `buscar_por_id()`).
* **Service** (`backend/services/`): uma classe por caso de uso, com um metodo `executar()`.
  E onde ficam as validacoes e as regras.
* **Repository** (`backend/repositories/`): so para consulta que nao e CRUD, tipo filtro por
  data de validade, busca com varios filtros e soma de vendas por periodo. O Service nao monta
  query, ele pede para o Repository.
* **Controller** (`backend/controllers/`): uma classe por recurso. Recebe a requisicao, chama o
  Service e devolve o JSON. Nao tem regra de negocio nem SQL.

No app Flutter: `models/` com as classes, `services/api_service.dart` com as chamadas http e
`screens/` com as telas. Sem gerenciador de estado, so `StatefulWidget` com `setState`.

## Funcionalidades Implementadas

Todas funcionam de ponta a ponta (tela -> API -> Controller -> Service -> Model/Repository -> banco):

1. Cadastro de empresa e usuarios
2. Login com autenticacao (e-mail e senha)
3. Controle de permissoes (admin e usuario comum)
4. Cadastro da chave de API do ERP
5. Integracao com ERP para importar produtos e vendas
6. Visualizacao do estoque atual
7. Dashboard com os indicadores principais
8. Historico de movimentacoes de estoque
9. Filtros de busca de produtos
10. Geracao de relatorios simples
11. Identificacao de produtos com baixo estoque
12. Identificacao de produtos parados (sem venda)
13. Lista de produtos mais vendidos
14. Previsao de demanda com base no historico
15. Sugestao de reposicao de estoque
16. Sugestao de reducao de estoque (evitar excesso)
17. Alertas inteligentes de falta ou excesso
18. Analise de fatores externos (eventos e clima)
19. Classificacao de produtos usando Curva ABC
20. Tela de recomendacoes com acoes sugeridas (comprar, reduzir, promover)
21. Controle de validade por lote e monitoramento de vencimentos
22. Alertas automaticos para produtos proximos do vencimento
23. Monitoramento das condicoes de armazenamento e temperatura
24. Priorizacao da venda dos produtos que vencem primeiro (PEPS)
25. Rastreamento de perdas e descartes por lote, com impacto financeiro
26. Importacao de categorias, produtos, vendas e eventos por CSV ou XLSX
27. Download de modelos de planilha pela tela de importacao

Alem dessas, o sistema tem o cadastro de categorias (usado pelos filtros e relatorios) e um
assistente que responde perguntas sobre o estoque usando a API do Gemini.

A importacao manual JSON por `POST /erp/importar` tambem permanece disponivel
para clientes da API, com as mesmas permissoes administrativas da integracao ERP.

## Compatibilidade corrigida apos a limpeza

As rotas `/erp/importar`, `/importar` e `/importar/modelo` foram recuperadas com
Controllers em classe. A importacao tem Services separados para coordenacao,
leitura, geracao de modelo e cada recurso; consultas especiais ficam nos
Repositories, e a persistencia fica nas Models. A inicializacao volta a adaptar
bancos antigos e preparar lotes e historico de forma idempotente. A venda preserva
a mesma regra PVPS na previa e na baixa e descarta respostas atrasadas da tela.

A comunicacao Flutter -> API direta e `GEMINI_MODEL` da branch de limpeza foram
mantidos. `NEXTSTOCK_API_URL` pode ser configurada com `--dart-define`, mantendo
`http://127.0.0.1:5000` como padrao. O proxy continua removido.

Validacao: **517 testes backend da branch**, **596 testes originais externos** e
**21 testes Flutter da branch** aprovados; analise estatica sem problemas e build
web concluido. Na previa local foram conferidos download XLSX, upload CSV,
persistencia, importacao ERP e respostas 401/403, sem erros JavaScript.
Os **133 testes Flutter externos da revisao anterior** tambem passaram usando
`NEXTSTOCK_API_URL` em 8000 para os contratos dos mocks; o padrao da aplicacao
continua sendo a API direta na porta 5000.

Detalhes das causas, arquitetura, testes e commits por funcionalidade:
[revisao da branch de limpeza](docs/REVISAO_BRANCH_LIMPEZA.md).

## Models

Sao 15 tabelas, todas herdando de `db.Model`:

| Model | Tabela | Para que serve |
|---|---|---|
| `Empresa` | empresa | a loja que usa o sistema |
| `Usuario` | usuario | quem faz login (admin ou usuario) |
| `Categoria` | categoria | categoria do produto |
| `Produto` | produto | o produto em si |
| `Lote` | lote | cada entrada de produto, com validade e custo |
| `MovimentacaoEstoque` | movimentacao_estoque | historico de tudo que entra e sai |
| `Venda` | venda | venda registrada |
| `Perda` | perda | descarte, com o prejuizo em reais |
| `LocalArmazenamento` | local_armazenamento | geladeira, camara fria, prateleira |
| `LeituraTemperatura` | leitura_temperatura | temperatura medida em um local |
| `Evento` | evento | evento da cidade que mexe na demanda |
| `ClimaDia` | clima_dia | clima de cada dia |
| `ConfiguracaoErp` | configuracao_erp | url e chave do ERP (chave criptografada) |
| `SincronizacaoErp` | sincronizacao_erp | historico das sincronizacoes |
| `ErpVendaImportada` | erp_venda_importada | evita importar a mesma venda duas vezes |

Principais relacionamentos: um produto pertence a uma categoria e pode ficar em um local de
armazenamento; um lote pertence a um produto; perda e movimentacao apontam para produto e lote;
usuario pertence a uma empresa.

## Repositories

Usamos Repository so onde a consulta nao e CRUD simples:

| Repository | O que faz |
|---|---|
| `ProdutoRepository` | produtos perto do vencimento, em risco de ruptura, busca com filtros |
| `LoteRepository` | lotes vencendo e lotes vencidos que ainda tem saldo |
| `VendaRepository` | vendas por periodo, por produto e total vendido |
| `EventoRepository` | eventos dentro de um periodo |
| `ClimaRepository` | clima de um periodo e gravacao em lote |

## Rotas da API

Sao 64 rotas. As principais:

| Grupo | Rotas |
|---|---|
| Login e setup | `POST /auth/login`, `GET /auth/me`, `POST /setup`, `GET /setup/status` |
| Empresa | `GET /empresa`, `PUT /empresa` |
| Usuarios | `GET POST /usuarios`, `PUT DELETE /usuarios/<id>` |
| Categorias | `GET POST /categorias`, `GET PUT DELETE /categorias/<id>` |
| Produtos | `GET POST /produtos`, `GET PUT DELETE /produtos/<id>` |
| Alertas de produto | `GET /produtos/vencendo`, `GET /produtos/risco-ruptura` |
| Lotes | `POST /lotes`, `PUT /lotes/<id>`, `GET /lotes/vencendo`, `GET /produtos/<id>/lotes`, `GET /produtos/<id>/ordem-saida` |
| Vendas | `GET POST /vendas`, `GET /vendas/previa` |
| Perdas | `GET POST /perdas`, `GET /perdas/resumo` |
| Movimentacoes | `GET /movimentacoes` |
| Alertas gerais | `GET /alertas/resumo`, `GET /alertas/excesso` |
| Armazenamento | `GET POST /locais-armazenamento`, `GET PUT DELETE /locais-armazenamento/<id>`, `GET POST /locais-armazenamento/<id>/leituras`, `GET /armazenamento/alertas` |
| Eventos e clima | `GET POST /eventos`, `DELETE /eventos/<id>`, `GET /clima` |
| Inteligencia | `GET /previsao`, `GET /compras/sugestoes`, `GET /reposicao`, `GET /recomendacoes`, `POST /assistente` |
| Relatorios | `GET /relatorios/consumo`, `/relatorios/desempenho`, `/relatorios/tendencias`, `/relatorios/curva-abc` |
| Painel | `GET /painel` |
| ERP | `GET PUT /erp/configuracao`, `DELETE /erp/configuracao/chave`, `POST /erp/testar-conexao`, `POST /erp/sincronizar`, `GET /erp/sincronizacoes` |

Exemplo de JSON para cadastrar um produto:

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

## Como rodar

Precisa de Python 3.10 ou mais novo, MySQL e o Flutter SDK. Sao duas partes, cada uma num terminal.

### 1. Backend (a API)

```bash
cd backend

python -m venv venv
venv\Scripts\activate        # linux/mac: source venv/bin/activate

pip install -r requirements.txt

# cria o banco e ja poe dados de exemplo
mysql -u root -p < database/create_database.sql

# copia o modelo do .env e poe a senha do seu mysql
copy .env.example .env       # linux/mac: cp .env.example .env

python app.py
```

A API fica em `http://127.0.0.1:5000`.

Se nao quiser instalar o MySQL so para testar, no `.env` deixe `DATABASE_URL=sqlite:///nextstock.db`.
A aplicacao cria as tabelas sozinha quando sobe.

### 2. Frontend (o app Flutter)

Com a API rodando, em outro terminal:

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

O endereco da API fica na constante `baseUrl`, em `frontend/lib/services/api_service.dart`.
Para web e desktop deixe `http://127.0.0.1:5000`. No emulador Android troque para
`http://10.0.2.2:5000`, que e como o emulador enxerga o localhost do PC.

### 3. Testes

Os testes do backend rodam com pytest e usam um banco SQLite em memoria, entao nao mexem no
banco de verdade:

```bash
cd backend
pip install -r requirements-dev.txt
pytest -q
```

Tem um arquivo de teste para cada funcionalidade principal (produtos, categorias, login, lotes,
ordem de saida, vendas, perdas, alertas, relatorios, curva ABC e previsao).

## Variaveis do .env

| Variavel | Para que serve |
|---|---|
| `DATABASE_URL` | conexao com o banco |
| `SECRET_KEY` | assina os tokens de login |
| `ERP_CHAVE_CRIPTOGRAFIA` | criptografa a chave do ERP antes de salvar no banco |
| `SENSOR_API_KEY` | chave que o sensor de temperatura manda para registrar leitura |
| `GEMINI_API_KEY` | chave do Gemini, usada so pelo assistente |
| `GEMINI_MODEL` | modelo do Gemini (padrao: `gemini-2.5-flash`) |
| `WEATHER_LAT`, `WEATHER_LON`, `WEATHER_CITY` | cidade usada para buscar o clima |

Nenhuma chave vai para o repositorio: o `.env` esta no `.gitignore` e o que vai versionado e so
o `.env.example`.

## Estrutura de pastas

```
NextStock/
├── backend/
│   ├── app.py                  # sobe a API e registra as rotas
│   ├── requirements.txt
│   ├── .env.example
│   ├── database/
│   │   └── create_database.sql # cria as tabelas e os dados de exemplo
│   ├── models/                 # as 15 tabelas (herdam de db.Model)
│   ├── services/               # uma classe por caso de uso
│   ├── repositories/           # as consultas que nao sao CRUD
│   ├── controllers/            # uma classe por recurso, com as rotas
│   └── tests/                  # testes com pytest
├── frontend/
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart           # entrada do app, tema e navegacao
│       ├── shell/              # menu lateral e tela de entrada
│       ├── models/             # as classes do app
│       ├── services/
│       │   └── api_service.dart # todas as chamadas http
│       └── screens/            # as telas
└── tools/                      # simuladores usados so para testar
    ├── erp_simulado/
    └── simular_sensor.py
```

## Simuladores (opcional)

### ERP simulado

Serve para testar a integracao com ERP sem ter um ERP de verdade. Ele ja vem com 5 produtos e
20 dias de vendas.

Antes, uma vez so: gere a chave de criptografia e coloque no `backend/.env`, depois reinicie a API.

```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

```
ERP_CHAVE_CRIPTOGRAFIA=<o texto gerado>
```

Com a API rodando, em outro terminal, na raiz do projeto:

```bash
python tools/erp_simulado/erp_simulado.py
```

Ele sobe em `http://127.0.0.1:5001`. No app, entre como administrador, abra **Integracao ERP**,
preencha a URL `http://127.0.0.1:5001` e a chave `chave-do-erp-simulado-123`, salve, clique em
**Testar conexao** e depois em **Sincronizar agora**. Os produtos e as vendas entram no sistema e
o resultado aparece no historico.

Os dados do simulado ficam so na memoria, entao fechou e abriu ele volta ao estado inicial. O que
ja foi sincronizado continua no banco do NextStock.

### Sensor de temperatura simulado

As leituras podem ser lancadas na tela (**Armazenamento**, abrir o local, "Registrar leitura") ou
chegar de um sensor. O `tools/simular_sensor.py` faz o papel do sensor.

Antes, uma vez so: gere a chave e coloque no `backend/.env` como `SENSOR_API_KEY`, depois
reinicie a API.

Crie o local no app (ex.: "Geladeira laticinios", de 0 a 5 graus), veja o numero dele no cartao
de cima (`Local #1`) e rode:

```bash
python tools/simular_sensor.py --local 1 --min 0 --max 5
```

Ele manda uma leitura a cada 5 segundos e, a cada 6 leituras, um pico fora da faixa para disparar
o alerta. Pare com Ctrl+C. Opcoes: `--intervalo`, `--pico-cada`, `--vezes` e `--chave`.
