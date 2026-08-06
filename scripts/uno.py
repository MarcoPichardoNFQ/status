import pandas as pd
import numpy as np
import json
import logging
import sys

# CONFIGURACIÓN
CONFIG = {
    "archivo_entrada": "ejecuciones.csv",
    "archivo_json": "datos_dashboard.json",
    "semanas_a_mostrar": 5,
    "colores": ["#38bdf8", "#818cf8", "#fb7185", "#34d399", "#fbbf24"]
}
import logging

logger = logging.getLogger(__name__)
def generar_escenario(df_datos, semanas_top, dias_orden):
    logger.info(f"Generando escenario para semanas: {semanas_top}")
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
    print("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    logger.info("Iniciando procesamiento de datos. aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    logger.info("Iniciando procesamiento de datos.")
    try:
        logger.info(f"Cargando archivo CSV: {CONFIG['archivo_entrada']}")
        df = pd.read_csv(CONFIG["archivo_entrada"], sep='|', dtype=str, quotechar='"')
        df.columns = [c.strip().lower() for c in df.columns]
        logger.info("CSV cargado y columnas limpiadas.")
        
        for col in df.columns:
            df[col] = df[col].astype(str).str.replace('"', '').str.strip()
            c= col
            #print(c)
        logger.info("Comillas y espacios eliminados de todas las columnas.")

        # 1. FIX ZONA HORARIA (Bug del Viernes)
        # Cortamos a 19 caracteres para ignorar el offset -0600 y mantener hora local literal
        # Elimina el timezone conservando la fecha, hora y fracción de segundo.
   
        fecha = (
            df['inicio_ejecucion']
            .str.replace(r'([+-]\d{2}:\d{2})$', '', regex=True)
            .str.replace(r'\.(\d{6})', '', regex=True)
        )

        df['inicio_dt'] = pd.to_datetime(
            fecha,
            format='%Y-%m-%d %H:%M:%S',
            errors='coerce'
        )
        df['inicio_dt']= df['inicio_dt'] - pd.Timedelta(hours=3)
        logger.info("el df se ve asi: ",df)
        c=df['inicio_dt']
        logger.info("Zona horaria ajustada y columna 'inicio_dt' creada.")

        # 2. Conversión de métricas
        df['duracion_min'] = pd.to_timedelta(df['duracion'], errors='coerce').dt.total_seconds() / 60.0
        df['tamano'] = pd.to_numeric(df['tamano'], errors='coerce').fillna(0)
        logger.info("Métricas 'duracion_min' y 'tamano' convertidas.")
        
        df = df.dropna(subset=['inicio_dt'])
        logger.info(f"Filas con 'inicio_dt' nulo eliminadas. Filas restantes: {len(df)}")
        # 3. Clasificación temporal
        df['año_semana'] = df['inicio_dt'].dt.strftime('%G-W%V')
        df['dia_num'] = df['inicio_dt'].dt.dayofweek
        df['dia_nombre_en'] = df['inicio_dt'].dt.day_name()
        df.to_csv('datos_usuarios.csv', index=False, encoding='utf-8')
        logger.info("Clasificación temporal ('año_semana', 'dia_num', 'dia_nombre_en') aplicada y 'datos_usuarios.csv' guardado.")
        # Filtrar solo Lunes a Viernes (0 a 4)
        df = df[df['dia_num'] < 5].copy()
        logger.info(f"Filtrando datos para incluir solo días de semana (Lunes-Viernes). Filas restantes: {len(df)}")
        
        semanas_top = sorted(df['año_semana'].unique(), reverse=True)[:CONFIG["semanas_a_mostrar"]]
        df_final = df[df['año_semana'].isin(semanas_top)].copy()
        logger.info(f"Semanas a mostrar: {semanas_top}. DataFrame final preparado con {len(df_final)} filas.")
        
        dias_orden = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
        ultimo_deploy = (df_final['inicio_dt'].max()).strftime('%Y-%m-%d %H:%M:%S') 
           
        # Generar Escenarios
        logger.info("Generando escenarios para duracion, tamano y volumen.")
        resultado = {
            "labels": ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'],
            "semanas": semanas_top,
            "ultimo_deploy": ultimo_deploy,
            "escenarios": {
                "todos": generar_escenario(df_final, semanas_top, dias_orden),
                "solo_auto": generar_escenario(df_final[df_final['tipo'].str.lower() == 'automatica'], semanas_top, dias_orden),
                "solo_ma": generar_escenario(df_final[df_final['tipo'].str.lower() != 'automatica'], semanas_top, dias_orden)
            }
        }

        with open(CONFIG["archivo_json"], "w", encoding="utf-8") as f:
            json.dump(resultado, f, indent=4)
        logger.info(f"Archivo {CONFIG['archivo_json']} generado con éxito.")
            
        # ========================================================
        # NUEVO: Exportar registros limpios para la Tab 6 (Auditoría)
        # ========================================================
        df_export = df_final[['id_camda', 'tipo', 'año_semana', 'dia_nombre_en', 'inicio_dt', 'duracion_min', 'tamano']].copy()
        df_export['inicio_dt'] = df_export['inicio_dt'].dt.strftime('%Y-%m-%d %H:%M:%S')
        df_export = df_export.replace({np.nan: None}) # Manejar posibles nulos para JSON
        
        datos_limpios = df_export.to_dict(orient='records')
        
        with open("datos_limpios.json", "w", encoding="utf-8") as f:
            json.dump(datos_limpios, f, indent=4)
        logger.info("Archivo 'datos_limpios.json' generado con éxito.")
        # ========================================================
        
        logger.info("Procesamiento de datos completado exitosamente.")
    except Exception as e:
        logger.error(f"ERROR CRÍTICO durante el procesamiento de datos: {e}", exc_info=True)


if __name__ == "__main__":
    logger.info("Iniciando procesamiento de datos. desde 1")
    procesar()