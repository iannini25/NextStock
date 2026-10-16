-- cria o banco do nextstock no mysql e ja poe uns dados de exemplo
-- roda uma vez:  mysql -u root -p < database/create_database.sql

CREATE DATABASE IF NOT EXISTS nextstock CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE nextstock;
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS categoria (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(60) NOT NULL,
    descricao VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS produto (
    id_produto INT AUTO_INCREMENT PRIMARY KEY,
    id_categoria INT,
    nome VARCHAR(150) NOT NULL,
    codigo_barras VARCHAR(50) UNIQUE,
    preco_custo DECIMAL(10,2),
    preco_venda DECIMAL(10,2) NOT NULL,
    quantidade_estoque INT DEFAULT 0,
    estoque_minimo INT DEFAULT 0,
    unidade VARCHAR(10) DEFAULT 'UN',
    data_validade DATE,
    FOREIGN KEY (id_categoria) REFERENCES categoria(id_categoria)
);

CREATE TABLE IF NOT EXISTS venda (
    id_venda INT AUTO_INCREMENT PRIMARY KEY,
    id_produto INT NOT NULL,
    quantidade INT NOT NULL,
    data_venda DATE NOT NULL,
    FOREIGN KEY (id_produto) REFERENCES produto(id_produto)
);

CREATE TABLE IF NOT EXISTS evento (
    id_evento INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    data_inicio DATE NOT NULL,
    data_fim DATE NOT NULL,
    impacto_percentual INT DEFAULT 0
);

-- clima baixado do Open-Meteo (sem chave). a api preenche sozinha.
CREATE TABLE IF NOT EXISTS clima_dia (
    data DATE PRIMARY KEY,
    temperatura FLOAT,
    chuva_mm FLOAT,
    condicao VARCHAR(20) NOT NULL,
    atualizado_em DATETIME
);

-- a empresa (o sistema atende uma so) e os usuarios dela.
-- nao tem dado de exemplo: a configuracao inicial do app cadastra a empresa e o primeiro admin.
CREATE TABLE IF NOT EXISTS empresa (
    id_empresa INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    nome_fantasia VARCHAR(150),
    cnpj VARCHAR(14) UNIQUE,
    email VARCHAR(150),
    telefone VARCHAR(20),
    criado_em DATETIME
);

-- a senha nunca fica salva, so o hash dela. usuario nao e apagado, so desativado.
CREATE TABLE IF NOT EXISTS usuario (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    id_empresa INT NOT NULL,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    senha_hash VARCHAR(255) NOT NULL,
    perfil VARCHAR(10) NOT NULL DEFAULT 'usuario',
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em DATETIME,
    FOREIGN KEY (id_empresa) REFERENCES empresa(id_empresa)
);

-- integracao com o ERP. a chave da API fica criptografada (nunca em texto puro).
CREATE TABLE IF NOT EXISTS configuracao_erp (
    id_configuracao INT AUTO_INCREMENT PRIMARY KEY,
    id_empresa INT NOT NULL UNIQUE,
    provedor VARCHAR(30) NOT NULL DEFAULT 'generico',
    url_base VARCHAR(255) NOT NULL,
    chave_criptografada TEXT,
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    atualizado_em DATETIME,
    atualizado_por INT,
    FOREIGN KEY (id_empresa) REFERENCES empresa(id_empresa),
    FOREIGN KEY (atualizado_por) REFERENCES usuario(id_usuario)
);

-- cada entrada de mercadoria vira um lote com quantidade, validade e custo proprios.
-- o estoque do produto e a soma dos lotes (a API cria o "estoque inicial" dos produtos antigos ao subir)
CREATE TABLE IF NOT EXISTS lote (
    id_lote INT AUTO_INCREMENT PRIMARY KEY,
    id_produto INT NOT NULL,
    codigo_lote VARCHAR(50),
    data_entrada DATE NOT NULL,
    data_validade DATE,
    quantidade_inicial INT NOT NULL,
    quantidade_atual INT NOT NULL,
    custo_unitario DECIMAL(10,2),
    origem VARCHAR(20) NOT NULL DEFAULT 'entrada',
    id_usuario INT,
    criado_em DATETIME,
    FOREIGN KEY (id_produto) REFERENCES produto(id_produto),
    FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario)
);

-- historico de tudo que entra e sai do estoque (quanto, de qual lote, saldo depois, quem, quando, de onde).
-- tipo: entrada | saldo_inicial | venda | ajuste_entrada | ajuste_saida | perda | descarte
-- origem: manual | planilha | erp | sistema | historico
CREATE TABLE IF NOT EXISTS movimentacao_estoque (
    id_movimentacao INT AUTO_INCREMENT PRIMARY KEY,
    id_produto INT NOT NULL,
    id_lote INT,
    tipo VARCHAR(20) NOT NULL,
    quantidade INT NOT NULL,
    saldo_produto_apos INT,
    custo_unitario DECIMAL(10,2),
    id_venda INT,
    id_usuario INT,
    origem VARCHAR(20) NOT NULL DEFAULT 'manual',
    observacao VARCHAR(255),
    data_hora DATETIME NOT NULL,
    FOREIGN KEY (id_produto) REFERENCES produto(id_produto),
    FOREIGN KEY (id_lote) REFERENCES lote(id_lote),
    FOREIGN KEY (id_venda) REFERENCES venda(id_venda),
    FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario)
);

-- historico de cada vez que o NextStock buscou dados no ERP
CREATE TABLE IF NOT EXISTS sincronizacao_erp (
    id_sincronizacao INT AUTO_INCREMENT PRIMARY KEY,
    iniciado_em DATETIME NOT NULL,
    finalizado_em DATETIME,
    status VARCHAR(20) NOT NULL DEFAULT 'em_andamento',
    produtos_criados INT NOT NULL DEFAULT 0,
    produtos_atualizados INT NOT NULL DEFAULT 0,
    vendas_importadas INT NOT NULL DEFAULT 0,
    vendas_ja_importadas INT NOT NULL DEFAULT 0,
    erros TEXT,
    id_usuario INT,
    FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario)
);

-- vendas que ja vieram do ERP (pelo id do ERP): sincronizar de novo nao duplica
CREATE TABLE IF NOT EXISTS erp_venda_importada (
    id_externo VARCHAR(100) PRIMARY KEY,
    id_venda INT NOT NULL,
    importado_em DATETIME NOT NULL,
    FOREIGN KEY (id_venda) REFERENCES venda(id_venda)
);

-- se voce ja tinha rodado esse script antes, roda essa linha na mao pra criar a coluna nova:
-- ALTER TABLE produto ADD COLUMN estoque_minimo INT DEFAULT 0 AFTER quantidade_estoque;

-- dados de exemplo
-- cada categoria so entra se ainda nao existir (rodar o script de novo nao duplica)
INSERT INTO categoria (nome, descricao)
SELECT 'Hortifruti', 'Frutas, legumes e verduras' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM categoria WHERE nome = 'Hortifruti');
INSERT INTO categoria (nome, descricao)
SELECT 'Laticínios', 'Leite, queijos e derivados' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM categoria WHERE nome = 'Laticínios');
INSERT INTO categoria (nome, descricao)
SELECT 'Padaria', 'Pães e produtos de panificação' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM categoria WHERE nome = 'Padaria');

-- as validades sao calculadas a partir de hoje pra tela de alerta sempre ter o que mostrar
INSERT INTO produto (id_categoria, nome, codigo_barras, preco_custo, preco_venda, quantidade_estoque, estoque_minimo, unidade, data_validade) VALUES
(1, 'Banana Prata (kg)',   '7890000000017', 3.50,  5.99,  40, 10, 'KG', DATE_ADD(CURDATE(), INTERVAL 2 DAY)),
(2, 'Leite Integral 1L',   '7890000000024', 3.20,  4.79, 120, 30, 'UN', DATE_ADD(CURDATE(), INTERVAL 45 DAY)),
(3, 'Pão Francês (kg)',    '7890000000031', 8.00, 14.90,  15,  5, 'KG', NULL),
(2, 'Iogurte Natural 170g','7890000000048', 1.80,  3.50,   4, 20, 'UN', DATE_ADD(CURDATE(), INTERVAL 5 DAY)),
(1, 'Alface Crespa (un)',  '7890000000055', 1.20,  2.99,   6, 15, 'UN', DATE_ADD(CURDATE(), INTERVAL 1 DAY));

-- vendas dos ultimos 60 dias, tambem a partir de hoje, pra previsao e relatorios terem historico.
-- leite (2) vende quase todo dia; banana (1) e pao (3) mais no fim de semana; iogurte (4) e alface (5) pouco
INSERT INTO venda (id_produto, quantidade, data_venda) VALUES
(2, 12, DATE_SUB(CURDATE(), INTERVAL 1 DAY)),
(2, 10, DATE_SUB(CURDATE(), INTERVAL 2 DAY)),
(2, 14, DATE_SUB(CURDATE(), INTERVAL 3 DAY)),
(2, 9,  DATE_SUB(CURDATE(), INTERVAL 4 DAY)),
(2, 11, DATE_SUB(CURDATE(), INTERVAL 5 DAY)),
(2, 13, DATE_SUB(CURDATE(), INTERVAL 6 DAY)),
(2, 10, DATE_SUB(CURDATE(), INTERVAL 8 DAY)),
(2, 12, DATE_SUB(CURDATE(), INTERVAL 9 DAY)),
(2, 8,  DATE_SUB(CURDATE(), INTERVAL 10 DAY)),
(2, 11, DATE_SUB(CURDATE(), INTERVAL 11 DAY)),
(2, 15, DATE_SUB(CURDATE(), INTERVAL 12 DAY)),
(2, 12, DATE_SUB(CURDATE(), INTERVAL 13 DAY)),
(2, 10, DATE_SUB(CURDATE(), INTERVAL 15 DAY)),
(2, 9,  DATE_SUB(CURDATE(), INTERVAL 16 DAY)),
(2, 13, DATE_SUB(CURDATE(), INTERVAL 17 DAY)),
(2, 11, DATE_SUB(CURDATE(), INTERVAL 18 DAY)),
(2, 10, DATE_SUB(CURDATE(), INTERVAL 19 DAY)),
(2, 14, DATE_SUB(CURDATE(), INTERVAL 20 DAY)),
(2, 12, DATE_SUB(CURDATE(), INTERVAL 22 DAY)),
(2, 9,  DATE_SUB(CURDATE(), INTERVAL 23 DAY)),
(2, 11, DATE_SUB(CURDATE(), INTERVAL 24 DAY)),
(2, 10, DATE_SUB(CURDATE(), INTERVAL 26 DAY)),
(2, 13, DATE_SUB(CURDATE(), INTERVAL 27 DAY)),
(2, 12, DATE_SUB(CURDATE(), INTERVAL 29 DAY)),
(2, 11, DATE_SUB(CURDATE(), INTERVAL 35 DAY)),
(2, 10, DATE_SUB(CURDATE(), INTERVAL 42 DAY)),
(2, 12, DATE_SUB(CURDATE(), INTERVAL 50 DAY)),
(2, 9,  DATE_SUB(CURDATE(), INTERVAL 58 DAY)),
(1, 8,  DATE_SUB(CURDATE(), INTERVAL 5 DAY)),
(1, 10, DATE_SUB(CURDATE(), INTERVAL 6 DAY)),
(1, 3,  DATE_SUB(CURDATE(), INTERVAL 9 DAY)),
(1, 9,  DATE_SUB(CURDATE(), INTERVAL 12 DAY)),
(1, 11, DATE_SUB(CURDATE(), INTERVAL 13 DAY)),
(1, 7,  DATE_SUB(CURDATE(), INTERVAL 19 DAY)),
(1, 10, DATE_SUB(CURDATE(), INTERVAL 20 DAY)),
(1, 8,  DATE_SUB(CURDATE(), INTERVAL 26 DAY)),
(1, 9,  DATE_SUB(CURDATE(), INTERVAL 27 DAY)),
(1, 6,  DATE_SUB(CURDATE(), INTERVAL 40 DAY)),
(3, 6,  DATE_SUB(CURDATE(), INTERVAL 5 DAY)),
(3, 7,  DATE_SUB(CURDATE(), INTERVAL 6 DAY)),
(3, 2,  DATE_SUB(CURDATE(), INTERVAL 10 DAY)),
(3, 5,  DATE_SUB(CURDATE(), INTERVAL 12 DAY)),
(3, 8,  DATE_SUB(CURDATE(), INTERVAL 13 DAY)),
(3, 6,  DATE_SUB(CURDATE(), INTERVAL 19 DAY)),
(3, 7,  DATE_SUB(CURDATE(), INTERVAL 20 DAY)),
(3, 5,  DATE_SUB(CURDATE(), INTERVAL 26 DAY)),
(3, 6,  DATE_SUB(CURDATE(), INTERVAL 27 DAY)),
(3, 4,  DATE_SUB(CURDATE(), INTERVAL 33 DAY)),
(4, 2,  DATE_SUB(CURDATE(), INTERVAL 3 DAY)),
(4, 1,  DATE_SUB(CURDATE(), INTERVAL 10 DAY)),
(4, 2,  DATE_SUB(CURDATE(), INTERVAL 24 DAY)),
(4, 3,  DATE_SUB(CURDATE(), INTERVAL 40 DAY)),
(5, 2,  DATE_SUB(CURDATE(), INTERVAL 2 DAY)),
(5, 1,  DATE_SUB(CURDATE(), INTERVAL 9 DAY)),
(5, 3,  DATE_SUB(CURDATE(), INTERVAL 17 DAY)),
(5, 2,  DATE_SUB(CURDATE(), INTERVAL 45 DAY));

-- eventos locais que mexem na demanda (um que ja passou e um que vem ai)
INSERT INTO evento (nome, data_inicio, data_fim, impacto_percentual) VALUES
('Feriado prolongado', DATE_SUB(CURDATE(), INTERVAL 20 DAY), DATE_SUB(CURDATE(), INTERVAL 18 DAY), 20),
('Festa junina do bairro', DATE_ADD(CURDATE(), INTERVAL 3 DAY), DATE_ADD(CURDATE(), INTERVAL 5 DAY), 30);
