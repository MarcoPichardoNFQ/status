
import pandas as pd
import json

archivo_excel = "dashboard_data_template.xlsx"

resultado = {}

for hoja in ["dbMegara", "dbReporting", "dbInfra","dbUAT"]:

    df = pd.read_excel(
        archivo_excel,
        sheet_name=hoja
    ).fillna("")

    # convierte timestamps a string
    for col in df.columns:

        if pd.api.types.is_datetime64_any_dtype(df[col]):

            df[col] = df[col].dt.strftime("%d/%m/%Y")

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

print("JSON generado correctamente")
