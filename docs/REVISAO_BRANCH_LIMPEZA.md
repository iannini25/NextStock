# Correções após a limpeza

Base: `dd0d589`, após `2ba40e4`. As onze falhas eram **onze casos de teste**, e
não onze módulos independentes. A causa comum era a remoção de três rotas e
seus fluxos: importação ERP, upload de planilhas e download do modelo.

## Contratos recuperados

| Casos que falhavam | Correção no código |
| --- | --- |
| `test_erp_importar_continua_igual` | Rota administrativa novamente registrada; resposta compatível com a configuração ERP existente |
| `test_sem_dados` | ImportarErpService recusa lote vazio com HTTP 400 e a mensagem anterior |
| `test_cria_produto_e_categoria_pelo_nome` | ImportarProdutoErpService cria produto/categoria pelas Models, depois de validar o item |
| `test_atualiza_produto_existente_e_zera_campos_nao_enviados` | Modo de importação manual preserva seus padrões; sincronização continua preservando campos omitidos |
| `test_venda_importada_baixa_o_estoque_do_produto_importado` | ImportarVendaErpService registra a venda com baixa; sincronização mantém venda e marcador na mesma transação sem nova baixa do saldo do ERP |
| `test_erros_ficam_na_lista_e_o_resto_e_importado` | Coordenador processa produtos antes das vendas e continua após erro de validação por item |
| `test_lista_de_rotas_so_admin_existe` | Três rotas restauradas e protegidas pelo decorator administrativo |
| Três variantes de `test_usuario_comum_recebe_403_nas_rotas_de_admin` | `/erp/importar`, `/importar` e `/importar/modelo` exigem administrador e respondem 403 ao perfil comum |
| `test_todas_as_rotas_atuais_continuam_registradas` | Blueprints e métodos HTTP restaurados, incluindo download de modelo e upload |

Os cinco erros de coleta também foram resolvidos. Voltaram os pontos públicos
de migração, importação de planilha, criação inicial de lotes, preenchimento
do histórico e consolidação de categorias. Os helpers de compatibilidade
delegam a classes, sem concentrar SQL ou regra nas Controllers.

## Organização das responsabilidades

- `ImportarController` trata HTTP; `GerarModeloPlanilhaService` gera o arquivo.
  `LerPlanilhaService` lê CSV/XLSX; `ImportarPlanilhaService` coordena os itens.
  Categoria, produto, venda e evento têm seu próprio Service de importação.
- `ImportarErpService` coordena; importadores de produto e venda validam e
  persistem cada item. As Models oferecem confirmação adiada para transações
  que envolvem saldo, lote, movimento, venda e marcador externo.
- `CategoriaRepository`, `ProdutoRepository`, `MovimentacaoRepository` e
  `SincronizacaoErpRepository` concentram consultas especiais. CRUD fica na Model.
- `MigrarArmazenamento`, em `infrastructure`, adapta a coluna antes das consultas.
  `PreencherHistoricoService` e `CriarLotesIniciaisService` preparam dados legados.
- `ConsolidarCategoriasService` mantém o menor ID, transfere produtos e remove
  duplicatas em uma transação; a prévia não grava. O script é apenas entrada CLI.
- `VerificarPermissaoService` avalia o perfil; o decorator limita-se à resposta
  HTTP e ao encaminhamento. Autenticação continua ocorrendo antes da autorização.

Foram mantidos acesso direto à API, `GEMINI_MODEL`, remoção do proxy e ausência
de carga de demonstração automática. Não houve restauração cega do repositório.
O ajuste do endereço por `NEXTSTOCK_API_URL` permite prévias em outra porta.

## Verificações

| Verificação | Resultado |
| --- | --- |
| Suíte versionada nesta branch | 517 testes backend aprovados |
| Suíte original de `8f17256`, executada externamente sem alterar testes | 596 aprovados, zero falhas e zero erros de coleta |
| Testes Flutter versionados na branch | 21 aprovados |
| Suíte Flutter externa da revisão anterior | 133 aprovados com `NEXTSTOCK_API_URL` em 8000, conforme os contratos de endereço dos mocks antigos |
| Análise estática Flutter | Sem problemas |
| Build web | Concluído; prévia aponta diretamente para a API 5010 |
| Navegador Edge | Download XLSX, escolha real de arquivo, upload CSV, saldo persistido, ERP manual, 401/403 e ausência de erros JavaScript |
| Banco antigo sem coluna de armazenamento | Coluna criada; produto consultável |
| Produto legado com saldo 12 e venda anterior | Um lote e duas movimentações após inicialização; sem repetição |

A suíte externa original ficou fora do commit: os testes restaurados na branch
cobrem as funcionalidades corrigidas. Entre as novas regressões estão falha ao
salvar marcador ERP, rollback após criação de lote na planilha, erro por linha,
rollback na consolidação e respostas atrasadas da prévia PVPS.

Testes e reproduções usam SQLite isolado/temporário. O navegador utiliza uma
cópia separada do banco de conferência. Não foi acessado MySQL ou ERP de produção.
A prévia desta branch está em **http://127.0.0.1:8092/**, enquanto os processos
locais estiverem ativos; a prévia anterior em 8091 não foi substituída.

## Commits por funcionalidade

| Commit | Funcionalidade |
| --- | --- |
| `d931e46` | PVPS/PEPS, prévia, baixa e transação da venda; Models compartilhadas necessárias ao estoque |
| `cd9e90c` | Entrada/correção de lotes e criação inicial idempotente |
| `07bc579` | Consultas, persistência e preenchimento de histórico de movimentações |
| `fb28ed4` | Importação/sincronização ERP por caso de uso e transação de venda/marcador |
| `ac5b7cd` | Importação e modelo de planilhas, Services por recurso e tela Flutter |
| `44d447c` | Migração de armazenamento na infraestrutura e preparação no startup |
| `b1ae8e7` | Consolidação de categorias, consulta especial e persistência pelas Models |
| `primeiro commit do boss` | Permissões em Service, testes das rotas/contratos e documentação do resultado |

Os arquivos e trechos de cada funcionalidade seguem o mapa local da revisão,
com adaptações às remoções da branch de limpeza. **A pasta `context` não faz
parte desses commits.** Bancos, credenciais, backups e arquivos temporários
também ficam fora do histórico.
