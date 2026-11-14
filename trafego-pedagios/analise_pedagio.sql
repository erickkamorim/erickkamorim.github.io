-- =====================================================================
-- EIXO · Tráfego nos pedágios das rodovias federais (ANTT, 2019 a 2021)
-- Pergunta: o fluxo de caminhões funciona como termômetro da economia?
--
-- Banco: SQLite (pedagio.db), tabela `trafego`, gerada por
--        scripts/carregar_dados.py a partir dos CSVs da ANTT.
-- Os números batem com o site (scripts/gerar_dados.py faz o mesmo em pandas).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Limpeza
--    * nomes com espaço sobrando e com maiúsculas diferentes
--      ("CONCEBRA" e "Concebra"). O UPPER do SQLite não converte letras
--      acentuadas, por isso os REPLACE antes dele.
--    * algumas concessionárias informaram por dia, outras por mês:
--      tudo vira mês com substr(data, 1, 7).
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS trafego_limpo;
CREATE VIEW trafego_limpo AS
SELECT
    UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(concessionaria),
          'ã','Ã'),'ç','Ç'),'é','É'),'í','Í'),'ó','Ó'),'á','Á'))            AS conc,
    UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(praca),
          'ã','Ã'),'ç','Ç'),'é','É'),'í','Í'),'ó','Ó'),'á','Á'),'ô','Ô'))     AS praca,
    substr(data, 1, 4)                                                       AS ano,
    substr(data, 1, 7)                                                       AS mes,
    tipo_de_veiculo                                                          AS tipo,
    TRIM(categoria)                                                          AS categoria,
    volume_total
FROM trafego;


-- ---------------------------------------------------------------------
-- 2. Comparação justa: só praças com os 36 meses informados
--    Contar por concessionária engana: a Via Sul abriu 5 praças em 2020
--    e a Ecovias do Cerrado começou em 2020. Somando por concessionária,
--    os caminhões "subiriam" 3,6% em 2020. Praça a praça, foi +0,2%.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS pracas_completas;
CREATE VIEW pracas_completas AS
SELECT conc, praca
FROM trafego_limpo
GROUP BY conc, praca
HAVING COUNT(DISTINCT mes) = 36;          -- 115 de 131 praças

DROP VIEW IF EXISTS painel;
CREATE VIEW painel AS
SELECT t.*
FROM trafego_limpo t
JOIN pracas_completas p ON p.conc = t.conc AND p.praca = t.praca;


-- ---------------------------------------------------------------------
-- 3. Totais por ano (milhões de veículos)
--    Esperado: Comercial 206,8 | 207,3 | 229,0
--              Passeio   401,2 | 354,8 | 386,0
-- ---------------------------------------------------------------------
SELECT ano,
       ROUND(SUM(CASE WHEN tipo = 'Comercial' THEN volume_total END) / 1e6, 1) AS comercial_mi,
       ROUND(SUM(CASE WHEN tipo = 'Passeio'   THEN volume_total END) / 1e6, 1) AS passeio_mi,
       ROUND(SUM(CASE WHEN tipo = 'Moto'      THEN volume_total END) / 1e6, 1) AS moto_mi
FROM painel
GROUP BY ano
ORDER BY ano;


-- ---------------------------------------------------------------------
-- 4. O choque de abril de 2020 contra abril de 2019
--    Esperado: comerciais -22,4% · passeio -44,7%
-- ---------------------------------------------------------------------
WITH abril AS (
    SELECT ano, tipo, SUM(volume_total) AS v
    FROM painel
    WHERE mes IN ('2019-04', '2020-04')
    GROUP BY ano, tipo
)
SELECT a20.tipo,
       ROUND((a20.v * 1.0 / a19.v - 1) * 100, 1) AS variacao_pct
FROM abril a20
JOIN abril a19 ON a19.tipo = a20.tipo AND a19.ano = '2019'
WHERE a20.ano = '2020' AND a20.tipo IN ('Comercial', 'Passeio');


-- ---------------------------------------------------------------------
-- 5. Termômetro: cada mês contra o mesmo mês de 2019
-- ---------------------------------------------------------------------
WITH mensal AS (
    SELECT mes, substr(mes, 6, 2) AS mm,
           SUM(CASE WHEN tipo = 'Comercial' THEN volume_total END) AS com,
           SUM(CASE WHEN tipo = 'Passeio'   THEN volume_total END) AS pas
    FROM painel
    GROUP BY mes
)
SELECT m.mes,
       ROUND((m.com * 1.0 / b.com - 1) * 100, 1) AS comercial_vs_2019,
       ROUND((m.pas * 1.0 / b.pas - 1) * 100, 1) AS passeio_vs_2019
FROM mensal m
JOIN mensal b ON b.mm = m.mm AND b.mes LIKE '2019%'
WHERE m.mes >= '2020-01'
ORDER BY m.mes;


-- ---------------------------------------------------------------------
-- 6. Participação dos comerciais no total, mês a mês
--    Em abril de 2020, 41,5% dos veículos eram comerciais (33,8% um ano antes)
-- ---------------------------------------------------------------------
SELECT mes,
       ROUND(SUM(CASE WHEN tipo = 'Comercial' THEN volume_total END) * 100.0 / SUM(volume_total), 1) AS part_comercial
FROM painel
GROUP BY mes
ORDER BY mes;


-- ---------------------------------------------------------------------
-- 7. Por concessionária: 2020 contra 2019, com ranking
-- ---------------------------------------------------------------------
WITH c AS (
    SELECT conc,
           SUM(CASE WHEN ano = '2019' AND tipo = 'Comercial' THEN volume_total END) AS com19,
           SUM(CASE WHEN ano = '2020' AND tipo = 'Comercial' THEN volume_total END) AS com20,
           SUM(CASE WHEN ano = '2019' AND tipo = 'Passeio'   THEN volume_total END) AS pas19,
           SUM(CASE WHEN ano = '2020' AND tipo = 'Passeio'   THEN volume_total END) AS pas20
    FROM painel
    GROUP BY conc
)
SELECT conc,
       ROUND((com20 * 1.0 / com19 - 1) * 100, 1) AS comercial_pct,
       ROUND((pas20 * 1.0 / pas19 - 1) * 100, 1) AS passeio_pct,
       RANK() OVER (ORDER BY pas20 * 1.0 / pas19) AS ranking_queda_passeio
FROM c
ORDER BY ranking_queda_passeio;


-- ---------------------------------------------------------------------
-- 8. Onde estão os caminhões: participação de comerciais por
--    concessionária em 2021
-- ---------------------------------------------------------------------
SELECT conc,
       ROUND(SUM(CASE WHEN tipo = 'Comercial' THEN volume_total END) * 100.0 / SUM(volume_total), 1) AS part_comercial_2021,
       RANK() OVER (ORDER BY SUM(CASE WHEN tipo = 'Comercial' THEN volume_total END) * 1.0 / SUM(volume_total) DESC) AS posicao
FROM painel
WHERE ano = '2021'
GROUP BY conc
ORDER BY posicao;
