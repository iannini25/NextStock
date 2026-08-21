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
