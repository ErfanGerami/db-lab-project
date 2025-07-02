import pyodbc

try:
    conn = pyodbc.connect(
        'DRIVER={ODBC Driver 17 for SQL Server};'
        'SERVER=localhost,1444;'
        'DATABASE=project;'
        'UID=erfang;'
        'PWD=salamsalam1'
    )
    print("Connection successful!")
    conn.close()
except Exception as e:
    print("Connection failed:", e)
