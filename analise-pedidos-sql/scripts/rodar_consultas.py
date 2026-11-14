"""
LUPA — carrega os CSVs da Olist em SQLite e roda as consultas de analise_pedidos.sql.

Uso: python rodar_consultas.py <pasta_com_os_csvs_da_olist>
Dados: Brazilian E-Commerce Public Dataset by Olist (Kaggle), CC BY-NC-SA 4.0.
"""
import sys, re, sqlite3
import pandas as pd

PASTA = sys.argv[1] if len(sys.argv) > 1 else "olist"
con = sqlite3.connect("olist.db")
for t in ["orders", "order_items", "customers", "sellers", "products", "order_reviews", "order_payments"]:
    pd.read_csv(f"{PASTA}/olist_{t}_dataset.csv").to_sql(t, con, if_exists="replace", index=False)

sql = open("../analise_pedidos.sql", encoding="utf-8").read()
con.executescript(sql[sql.index("DROP VIEW"):sql.index("-- @q1")])
partes = re.split(r"-- @(q\d)\n", sql)
for i in range(1, len(partes), 2):
    consulta = partes[i + 1].split("\n-- ----")[0].strip().rstrip(";")
    print(f"\n=== {partes[i]} ===")
    print(pd.read_sql(consulta, con).to_string(index=False))
