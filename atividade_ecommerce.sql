DELIMITER $$

CREATE PROCEDURE sp_registrar_venda(
    IN  p_cliente_id INT,
    OUT p_venda_id   INT
)
BEGIN

    INSERT INTO vendas (data_venda, valor_total, status_venda, cliente_id, data_criacao, data_atualizacao)
    VALUES (NOW(), 0.00, 'P', p_cliente_id, NOW(), NOW());

    SET p_venda_id = LAST_INSERT_ID();

END$$

DELIMITER ;


DELIMITER $$

CREATE PROCEDURE sp_adicionar_item_venda(
    IN p_venda_id   INT,
    IN p_produto_id INT,
    IN p_qtde_venda DECIMAL(10,3)
)
BEGIN

    DECLARE v_estoque    DECIMAL(10,3);
    DECLARE v_preco      DECIMAL(10,2);
    DECLARE v_total_item DECIMAL(10,2);

    SELECT estoque, preco_unitario
    INTO   v_estoque, v_preco
    FROM   produtos
    WHERE  produto_id = p_produto_id;

    IF v_estoque < p_qtde_venda THEN

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Erro: estoque insuficiente para este produto.';

    ELSE

        SET v_total_item = p_qtde_venda * v_preco;

        INSERT INTO itens_vendas (qtde_venda, valor_venda, venda_id, produto_id, data_criacao, data_atualizacao)
        VALUES (p_qtde_venda, v_total_item, p_venda_id, p_produto_id, NOW(), NOW());

    END IF;

END$$

DELIMITER ;


DELIMITER $$

CREATE FUNCTION fn_calcular_total_item(
    p_qtde_venda  DECIMAL(10,3),
    p_valor_venda DECIMAL(10,2)
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN

    RETURN p_qtde_venda * p_valor_venda;

END$$

DELIMITER ;


DELIMITER $$

CREATE FUNCTION fn_verificar_estoque_critico(
    p_produto_id INT
)
RETURNS INT
DETERMINISTIC
BEGIN

    DECLARE v_estoque     DECIMAL(10,3);
    DECLARE v_estoque_min DECIMAL(10,3);

    SELECT estoque, estoque_min
    INTO   v_estoque, v_estoque_min
    FROM   produtos
    WHERE  produto_id = p_produto_id;

    IF v_estoque < v_estoque_min THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;

END$$

DELIMITER ;


DELIMITER $$

CREATE TRIGGER tg_atualizar_estoque_venda
AFTER INSERT ON itens_vendas
FOR EACH ROW
BEGIN

    UPDATE produtos
    SET    estoque          = estoque - NEW.qtde_venda,
           data_atualizacao = NOW()
    WHERE  produto_id = NEW.produto_id;

END$$

DELIMITER ;


DELIMITER $$

CREATE TRIGGER tg_atualizar_total_venda_insert
AFTER INSERT ON itens_vendas
FOR EACH ROW
BEGIN

    UPDATE vendas
    SET    valor_total      = (
               SELECT COALESCE(SUM(valor_venda), 0)
               FROM   itens_vendas
               WHERE  venda_id = NEW.venda_id
           ),
           data_atualizacao = NOW()
    WHERE  venda_id = NEW.venda_id;

END$$

DELIMITER ;


DELIMITER $$

CREATE TRIGGER tg_atualizar_total_venda_delete
AFTER DELETE ON itens_vendas
FOR EACH ROW
BEGIN

    UPDATE vendas
    SET    valor_total      = (
               SELECT COALESCE(SUM(valor_venda), 0)
               FROM   itens_vendas
               WHERE  venda_id = OLD.venda_id
           ),
           data_atualizacao = NOW()
    WHERE  venda_id = OLD.venda_id;

END$$

DELIMITER ;
