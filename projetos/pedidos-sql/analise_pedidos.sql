-- =====================================================================
-- Análise de Pedidos com SQL — Olist (e-commerce brasileiro, 2016–2018)
-- Autor: Erick Amorim
-- Banco: SQLite 3 (as consultas usam CTEs, CASE, funções de janela e
--        JULIANDAY para calcular intervalos em dias)
-- Fonte: Brazilian E-Commerce Public Dataset by Olist (Kaggle),
--        licença CC BY-NC-SA 4.0
-- =====================================================================

-- ---------------------------------------------------------------------
-- Base comum: pedidos entregues com todas as datas preenchidas.
-- Todas as perguntas abaixo partem desta view.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS vw_entregas;
CREATE VIEW vw_entregas AS
SELECT
    o.order_id,
    c.customer_state                                   AS uf_cliente,
    DATE(o.order_purchase_timestamp)                   AS data_compra,
    STRFTIME('%Y-%m', o.order_purchase_timestamp)      AS mes,
    JULIANDAY(o.order_approved_at)            - JULIANDAY(o.order_purchase_timestamp)     AS dias_aprovacao,
    JULIANDAY(o.order_delivered_carrier_date) - JULIANDAY(o.order_approved_at)            AS dias_postagem,
    JULIANDAY(o.order_delivered_customer_date)- JULIANDAY(o.order_delivered_carrier_date) AS dias_transporte,
    JULIANDAY(o.order_delivered_customer_date)- JULIANDAY(o.order_purchase_timestamp)     AS lead_time,
    JULIANDAY(DATE(o.order_delivered_customer_date)) - JULIANDAY(DATE(o.order_estimated_delivery_date)) AS dias_vs_prazo,
    CASE WHEN DATE(o.order_delivered_customer_date) <= DATE(o.order_estimated_delivery_date)
         THEN 1 ELSE 0 END                             AS no_prazo
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_approved_at              IS NOT NULL
  AND o.order_delivered_carrier_date   IS NOT NULL
  AND o.order_delivered_customer_date  IS NOT NULL
  AND o.order_estimated_delivery_date  IS NOT NULL
  AND o.order_delivered_carrier_date  >= o.order_approved_at;   -- descarta registros com datas invertidas

-- ---------------------------------------------------------------------
-- Q1. Como está a operação no geral?
-- ---------------------------------------------------------------------
-- @q1
SELECT
    COUNT(*)                                          AS pedidos_entregues,
    ROUND(100.0 * AVG(no_prazo), 1)                   AS pct_no_prazo,
    ROUND(AVG(lead_time), 1)                          AS lead_time_medio_dias,
    ROUND(AVG(CASE WHEN no_prazo = 0 THEN dias_vs_prazo END), 1) AS atraso_medio_dos_atrasados,
    ROUND(AVG(CASE WHEN no_prazo = 1 THEN -dias_vs_prazo END), 1) AS folga_media_dos_no_prazo
FROM vw_entregas;

-- ---------------------------------------------------------------------
-- Q2. Em quais meses o nível de serviço caiu?
-- (meses com pelo menos 500 pedidos, para evitar distorção)
-- ---------------------------------------------------------------------
-- @q2
SELECT
    mes,
    COUNT(*)                         AS pedidos,
    ROUND(100.0 * AVG(no_prazo), 1)  AS pct_no_prazo,
    ROUND(AVG(lead_time), 1)         AS lead_time_medio
FROM vw_entregas
GROUP BY mes
HAVING COUNT(*) >= 500
ORDER BY mes;

-- ---------------------------------------------------------------------
-- Q3. Onde o tempo de entrega é gasto?
-- Quebra o lead time em três etapas.
-- ---------------------------------------------------------------------
-- @q3
SELECT 'Aprovação do pagamento' AS etapa, ROUND(AVG(dias_aprovacao), 1) AS dias_medios FROM vw_entregas
UNION ALL
SELECT 'Vendedor até a transportadora', ROUND(AVG(dias_postagem), 1) FROM vw_entregas
UNION ALL
SELECT 'Transporte até o cliente', ROUND(AVG(dias_transporte), 1) FROM vw_entregas;

-- ---------------------------------------------------------------------
-- Q4. Quais estados recebem com mais atraso?
-- Ranking com função de janela (estados com 300+ pedidos).
-- ---------------------------------------------------------------------
-- @q4
WITH por_uf AS (
    SELECT
        uf_cliente,
        COUNT(*)                                AS pedidos,
        ROUND(100.0 * (1 - AVG(no_prazo)), 1)   AS pct_atraso,
        ROUND(AVG(lead_time), 1)                AS lead_time_medio
    FROM vw_entregas
    GROUP BY uf_cliente
    HAVING COUNT(*) >= 300
)
SELECT
    RANK() OVER (ORDER BY pct_atraso DESC) AS ranking,
    uf_cliente, pedidos, pct_atraso, lead_time_medio
FROM por_uf
ORDER BY ranking
LIMIT 10;

-- ---------------------------------------------------------------------
-- Q5. Quando o vendedor posta depois do limite, o atraso aumenta?
-- Compara a data de postagem com o shipping_limit_date do item.
-- ---------------------------------------------------------------------
-- @q5
WITH limite AS (
    SELECT order_id, MIN(shipping_limit_date) AS limite_postagem
    FROM order_items
    GROUP BY order_id
)
SELECT
    CASE WHEN o.order_delivered_carrier_date > l.limite_postagem
         THEN 'Postou depois do limite' ELSE 'Postou dentro do limite' END AS postagem,
    COUNT(*)                                     AS pedidos,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_dos_pedidos,
    ROUND(100.0 * (1 - AVG(e.no_prazo)), 1)      AS pct_entregue_atrasado
FROM vw_entregas e
JOIN orders o ON o.order_id = e.order_id
JOIN limite l ON l.order_id = e.order_id
GROUP BY postagem
ORDER BY pct_entregue_atrasado DESC;

-- ---------------------------------------------------------------------
-- Q6. O atraso derruba a satisfação do cliente?
-- Nota média da avaliação por faixa de atraso.
-- ---------------------------------------------------------------------
-- @q6
WITH nota AS (
    SELECT order_id, AVG(review_score) AS nota
    FROM order_reviews
    GROUP BY order_id
)
SELECT
    CASE
        WHEN e.dias_vs_prazo <= 0  THEN '1. No prazo'
        WHEN e.dias_vs_prazo <= 3  THEN '2. 1 a 3 dias de atraso'
        WHEN e.dias_vs_prazo <= 7  THEN '3. 4 a 7 dias de atraso'
        ELSE                            '4. Mais de 7 dias de atraso'
    END                                         AS faixa,
    COUNT(*)                                    AS pedidos,
    ROUND(AVG(n.nota), 2)                       AS nota_media,
    ROUND(100.0 * AVG(CASE WHEN n.nota <= 2 THEN 1.0 ELSE 0 END), 1) AS pct_notas_1_ou_2
FROM vw_entregas e
JOIN nota n ON n.order_id = e.order_id
GROUP BY faixa
ORDER BY faixa;

-- ---------------------------------------------------------------------
-- Q7. Quais rotas (UF do vendedor -> UF do cliente) mais atrasam?
-- Rotas com 500+ pedidos.
-- ---------------------------------------------------------------------
-- @q7
WITH rota AS (
    SELECT DISTINCT e.order_id, s.seller_state || ' → ' || e.uf_cliente AS rota, e.no_prazo, e.lead_time
    FROM vw_entregas e
    JOIN order_items i ON i.order_id = e.order_id
    JOIN sellers s     ON s.seller_id = i.seller_id
)
SELECT
    rota,
    COUNT(*)                               AS pedidos,
    ROUND(100.0 * (1 - AVG(no_prazo)), 1)  AS pct_atraso,
    ROUND(AVG(lead_time), 1)               AS lead_time_medio
FROM rota
GROUP BY rota
HAVING COUNT(*) >= 500
ORDER BY pct_atraso DESC
LIMIT 8;

-- ---------------------------------------------------------------------
-- Q8. O prazo prometido é realista?
-- Distribuição da diferença entre entrega real e prazo estimado.
-- ---------------------------------------------------------------------
-- @q8
SELECT
    CASE
        WHEN dias_vs_prazo <= -15 THEN '1. 15+ dias antes do prazo'
        WHEN dias_vs_prazo <= -8  THEN '2. 8 a 14 dias antes'
        WHEN dias_vs_prazo <= -1  THEN '3. 1 a 7 dias antes'
        WHEN dias_vs_prazo  =  0  THEN '4. No dia do prazo'
        ELSE                           '5. Depois do prazo'
    END                                              AS chegada,
    COUNT(*)                                         AS pedidos,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM vw_entregas
GROUP BY chegada
ORDER BY chegada;
