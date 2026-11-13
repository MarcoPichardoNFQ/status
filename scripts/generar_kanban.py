import datetime
import json
import os
import re
import subprocess
from pathlib import Path

# --- CONFIGURACIÓN ---
REPO_TICKETS_URL = os.getenv("REPO_TICKETS_URL", "https://github.com/marcopichardonfq/tickets.git")
RAMA_TICKETS = "main"

CACHE_DIR = Path(__file__).resolve().parents[1] / ".cache_vault"
OUTPUT_JSON = Path(__file__).resolve().parents[1] / "tickets_kanban.json"

ESTADOS_FALLBACK = [
    "Abierto",
    "En curso",
    "Revisión cliente",
    "Pendiente despliegue UAT",
    "Pruebas cliente UAT",
    "Pendiente despliegue PRD",
    "Resuelto",
]

def sync_carpetas_especificas() -> Path:
    if not (CACHE_DIR / ".git").exists():
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "init"], cwd=CACHE_DIR, check=True, capture_output=True)
        subprocess.run(["git", "remote", "add", "origin", REPO_TICKETS_URL], cwd=CACHE_DIR, check=True, capture_output=True)
        subprocess.run(["git", "config", "core.sparseCheckout", "true"], cwd=CACHE_DIR, check=True, capture_output=True)
        subprocess.run(["git", "config", "core.quotePath", "false"], cwd=CACHE_DIR, check=True, capture_output=True)

        sparse_file = CACHE_DIR / ".git" / "info" / "sparse-checkout"
        sparse_file.write_text("02_TICKETS/Abiertos/\n05_GENERAL/listas.json\n", encoding="utf-8")

    subprocess.run(
        ["git", "pull", "--depth=1", "origin", RAMA_TICKETS],
        cwd=CACHE_DIR,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return CACHE_DIR

def cargar_estados(vault_dir: Path) -> list[str]:
    listas_path = vault_dir / "05_GENERAL" / "listas.json"
    if listas_path.exists():
        data = json.loads(listas_path.read_text(encoding="utf-8"))
        if isinstance(data.get("estado"), list) and data["estado"]:
            return data["estado"]
    return ESTADOS_FALLBACK

def parse_ticket(filepath: Path) -> dict:
    text = filepath.read_text(encoding="utf-8")
    fm = {}
    body = text

    m = re.match(r"^---\r?\n(.*?)\r?\n---", text, re.S)
    if m:
        body = text[m.end():].strip()
        key = None
        for line in m.group(1).splitlines():
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if line.startswith(" ") and key:
                item = line.strip()
                if item.startswith("- ") and isinstance(fm.get(key), list):
                    fm[key].append(item[2:].strip().strip('"').strip("'"))
                continue
            if ":" not in line:
                continue
            key, _, val = line.partition(":")
            key = key.strip()
            val = val.split("#", 1)[0].strip()
            if val.startswith("[") and val.endswith("]"):
                fm[key] = [v.strip().strip('"').strip("'") for v in val[1:-1].split(",") if v.strip()]
            elif val == "":
                fm[key] = [] if key in ("categoria", "entorno", "tags") else ""
            else:
                fm[key] = val.strip('"').strip("'")

    name_match = re.match(r"^(NFQBAU-\d+)\s+[—-]\s+(\d{4}-\d{2}-\d{2})\s+[—-]\s+(.*?)\.md$", filepath.name)
    if name_match:
        ticket_id = fm.get("id") or name_match.group(1)
        fecha_nombre = name_match.group(2)
        titulo = name_match.group(3)
    else:
        ticket_id = fm.get("id") or filepath.stem[:11]
        fecha_nombre = fm.get("fecha_apertura", "")
        titulo = filepath.stem

    resumen = ""
    sec_res = re.search(r"## Resumen\s*\r?\n(.*?)(?=\r?\n## |\Z)", body, re.S)
    if sec_res:
        resumen = sec_res.group(1).strip()

    historico = ""
    sec_hist = re.search(r"## Histórico de interacciones\s*\r?\n(.*?)(?=\r?\n## |\Z)", body, re.S)
    if sec_hist:
        historico = sec_hist.group(1).strip()

    hoy = datetime.date.today().isoformat()
    fecha_limite = str(fm.get("fecha_limite", ""))
    estado = str(fm.get("estado", "Abierto")) or "Abierto"
    vencido = bool(fecha_limite and estado == "Abierto" and fecha_limite < hoy)

    return {
        "id": ticket_id,
        "titulo": titulo,
        "estado": estado,
        "prioridad": str(fm.get("prioridad", "Media")) or "Media",
        "responsable": str(fm.get("responsable", "")) or "Sin asignar",
        "categoria": fm.get("categoria") if isinstance(fm.get("categoria"), list) else [],
        "entorno": fm.get("entorno") if isinstance(fm.get("entorno"), list) else [],
        "fecha_apertura": str(fm.get("fecha_apertura", fecha_nombre)),
        "fecha_limite": fecha_limite,
        "actualizado": str(fm.get("actualizado", "")),
        "sintoma": str(fm.get("sintoma", "")),
        "resumen": resumen,
        "historico": historico,
        "vencido": vencido,
    }

def generar():
    vault_dir = sync_carpetas_especificas()
    estados = cargar_estados(vault_dir)
    dir_abiertos = vault_dir / "02_TICKETS" / "Abiertos"

    tickets = []
    if dir_abiertos.exists():
        for filepath in sorted(dir_abiertos.glob("NFQBAU-*.md")):
            tickets.append(parse_ticket(filepath))

    tickets.sort(key=lambda x: x["id"], reverse=True)

    payload = {
        "actualizado": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "estados": estados,
        "tickets": tickets,
    }

    OUTPUT_JSON.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"tickets_kanban.json generado con {len(tickets)} tickets.")

if __name__ == "__main__":
    generar()