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
    unidade VARCHAR(10) DEFAULT 'UN',
    data_validade DATE,
    FOREIGN KEY (id_categoria) REFERENCES categoria(id_categoria)
);

-- dados de exemplo
INSERT INTO categoria (nome, descricao) VALUES
('Hortifruti', 'Frutas, legumes e verduras'),
('Laticínios', 'Leite, queijos e derivados'),
('Padaria', 'Pães e produtos de panificação');

INSERT INTO produto (id_categoria, nome, codigo_barras, preco_custo, preco_venda, quantidade_estoque, unidade, data_validade) VALUES
(1, 'Banana Prata (kg)', '7890000000017', 3.50, 5.99, 40, 'KG', '2026-07-10'),
(2, 'Leite Integral 1L', '7890000000024', 3.20, 4.79, 120, 'UN', '2026-09-01'),
(3, 'Pão Francês (kg)', '7890000000031', 8.00, 14.90, 15, 'KG', NULL);
