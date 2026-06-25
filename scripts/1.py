import pandas as pd
import numpy as np
import json
import sys

# CONFIGURACIÓN
CONFIG = {
    "archivo_entrada": "ejecuciones.csv",
    "archivo_json": "datos_dashboard.json",
    "semanas_a_mostrar": 5,
    "colores": ["#38bdf8", "#818cf8", "#fb7185", "#34d399", "#fbbf24"]
}

def generar_escenario(df_datos, semanas_top, dias_orden):
    d_duracion, d_tamano, d_vol = [], [], []
    
    for i, sem in enumerate(semanas_top):
        color = CONFIG["colores"][i % len(CONFIG["colores"])]
        df_sem = df_datos[df_datos['año_semana'] == sem]

        if df_sem.empty:
            continue

        # Calculamos promedios por día
        # REEMPLAZO CRITICO: .replace({np.nan: None}) permite que Chart.js vea 'null' y no '0'
        dur_data = df_sem.groupby('dia_nombre_en')['duracion_min'].mean().reindex(dias_orden).replace({np.nan: None}).tolist()
        tam_data = df_sem.groupby('dia_nombre_en')['tamano'].mean().reindex(dias_orden).replace({np.nan: None}).tolist()
        vol_data = df_sem.groupby('dia_nombre_en').size().reindex(dias_orden).replace({np.nan: None}).tolist()

        d_duracion.append({"label": sem, "data": dur_data, "borderColor": color, "tension": 0.3, "fill": False})
        d_tamano.append({"label": sem, "data": tam_data, "borderColor": color, "backgroundColor": color + "20", "tension": 0.3, "fill": True})
        d_vol.append({"label": sem, "data": vol_data, "borderColor": color, "tension": 0.3, "fill": False})

    # Datos para Radar y Dona (Basados en todo el histórico filtrado)
    conteo_tipo = df_datos['tipo'].value_counts().to_dict()
    df_radar = df_datos.groupby('dia_nombre_en').agg(
        vol=('id_camda', 'count'), 
        dur=('duracion_min', 'mean'), 
        tam=('tamano', 'mean')
    ).reindex(dias_orden).fillna(0)

    return {
        "lineas_duracion": d_duracion,
        "lineas_tamano": d_tamano,
        "lineas_volumen": d_vol,
        "dona": {"labels": list(conteo_tipo.keys()), "data": list(conteo_tipo.values())},
        "radar": {
            "vol": (df_radar['vol'] / df_radar['vol'].max() * 100).tolist() if df_radar['vol'].max() > 0 else [0]*5,
            "dur": (df_radar['dur'] / df_radar['dur'].max() * 100).tolist() if df_radar['dur'].max() > 0 else [0]*5,
            "tam": (df_radar['tam'] / df_radar['tam'].max() * 100).tolist() if df_radar['tam'].max() > 0 else [0]*5
        }
    }

def procesar():
    print("🚀 Iniciando procesamiento de datos...")
    try:
        # Carga robusta de CSV
        df = pd.read_csv(CONFIG["archivo_entrada"], sep='|', dtype=str, quotechar='"')
        df.columns = [c.strip().lower() for c in df.columns]
        
        # Limpieza de comillas y espacios
        for col in df.columns:
            df[col] = df[col].astype(str).str.replace('"', '').str.strip()

        # 1. FIX ZONA HORARIA (Bug del Viernes)
        # Cortamos a 19 caracteres para ignorar el offset -0600 y mantener hora local literal
        df['inicio_dt'] = pd.to_datetime(df['inicio_ejecucion'].str.slice(0, 19), errors='coerce')
        
        # 2. Conversión de métricas
        df['duracion_min'] = pd.to_timedelta(df['duracion'], errors='coerce').dt.total_seconds() / 60.0
        df['tamano'] = pd.to_numeric(df['tamano'], errors='coerce').fillna(0)
        
        df = df.dropna(subset=['inicio_dt'])

        # 3. Clasificación temporal
        df['año_semana'] = df['inicio_dt'].dt.strftime('%G-W%V')
        df['dia_num'] = df['inicio_dt'].dt.dayofweek
        df['dia_nombre_en'] = df['inicio_dt'].dt.day_name()
        
        # Filtrar solo Lunes a Viernes (0 a 4)
        df = df[df['dia_num'] < 5].copy()
        
        semanas_top = sorted(df['año_semana'].unique(), reverse=True)[:CONFIG["semanas_a_mostrar"]]
        df_final = df[df['año_semana'].isin(semanas_top)].copy()
        
        dias_orden = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
        
        # Generar Escenarios
        resultado = {
            "labels": ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'],
            "semanas": semanas_top,
            "escenarios": {
                "todos": generar_escenario(df_final, semanas_top, dias_orden),
                "solo_auto": generar_escenario(df_final[df_final['tipo'].str.lower() == 'automatica'], semanas_top, dias_orden),
                "solo_ma": generar_escenario(df_final[df_final['tipo'].str.lower() != 'automatica'], semanas_top, dias_orden)
            }
        }

        with open(CONFIG["archivo_json"], "w", encoding="utf-8") as f:
            json.dump(resultado, f, indent=4)
            
        # ========================================================
        # NUEVO: Exportar registros limpios para la Tab 6 (Auditoría)
        # ========================================================
        df_export = df_final[['id_camda', 'tipo', 'año_semana', 'dia_nombre_en', 'inicio_dt', 'duracion_min', 'tamano']].copy()
        df_export['inicio_dt'] = df_export['inicio_dt'].dt.strftime('%Y-%m-%d %H:%M:%S')
        df_export = df_export.replace({np.nan: None}) # Manejar posibles nulos para JSON
        
        datos_limpios = df_export.to_dict(orient='records')
        
        with open("datos_limpios.json", "w", encoding="utf-8") as f:
            json.dump(datos_limpios, f, indent=4)
        # ========================================================
        
        print(f"✅ Archivo {CONFIG['archivo_json']} y datos_limpios.json generados con éxito.")

    except Exception as e:
        print(f"❌ ERROR CRÍTICO: {e}")

if __name__ == "__main__":
    procesar()
