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

-- se voce ja tinha rodado esse script antes, roda essa linha na mao pra criar a coluna nova:
-- ALTER TABLE produto ADD COLUMN estoque_minimo INT DEFAULT 0 AFTER quantidade_estoque;

-- dados de exemplo
INSERT INTO categoria (nome, descricao) VALUES
('Hortifruti', 'Frutas, legumes e verduras'),
('Laticínios', 'Leite, queijos e derivados'),
('Padaria', 'Pães e produtos de panificação');

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
