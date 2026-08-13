import pandas as pd
import json
from datetime import datetime, date

archivo_excel = "dashboard_data_template.xlsx"

resultado = {}


def convertir_valor(valor):
    """
    Convierte valores no serializables a tipos compatibles con JSON.

    Las fechas/timestamps se convierten al formato:
    DD/MM/YYYY
    """

    if isinstance(valor, (pd.Timestamp, datetime, date)):
        return valor.strftime("%d/%m/%Y")

    return valor


for hoja in ["dbMegara", "dbReporting", "dbInfra", "dbUAT"]:

    df = pd.read_excel(
        archivo_excel,
        sheet_name=hoja
    )

    # Reemplaza valores nulos.
    df = df.fillna("")

    # Convierte cualquier datetime/Timestamp encontrado,
    # independientemente del dtype de la columna.
    df = df.map(convertir_valor)

    resultado[hoja] = df.to_dict(
        orient="records"
    )


with open(
    "data.json",
    "w",
    encoding="utf-8"
) as f:

    json.dump(
        resultado,
        f,
        ensure_ascii=False,
        indent=4
    )

# print("JSON generado correctamente")