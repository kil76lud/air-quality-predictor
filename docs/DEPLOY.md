# Guía de despliegue inicial (Hugging Face Spaces + GitHub Actions)

## 0. Requisitos
Python 3.11, Git, Docker (opcional en local), cuenta de GitHub y de Hugging Face (ambas gratis).

## 1. Datos reales y primer champion (local, una sola vez)
```bash
python3.11 -m venv .venv && source .venv/bin/activate
make install
make first-run          # download -> ingest --reset -> train --force-promote (con MLflow)
```
Revisa que `models/reports/class_distribution.png` muestre **al menos 2-3 clases** y que
`models/champion/metadata.json` tenga `"data_source": "open-meteo"`. En Puno son esperables
muchas horas Good/Moderate y pocas (o ninguna) de las clases altas: es una **propiedad de los
datos**, el código lo soporta y se explica en el informe.
Si Open-Meteo falla durante el bootstrap, reintenta; el pipeline NO inventa datos reales.

Abre MLflow para verificar: `make mlflow-ui` → experimento `air-quality-aqi`, modelo registrado
`aqi-category-classifier` con alias **champion**.

## 2. Repositorio en GitHub
```bash
git init -b main && git add . && git commit -m "Initial commit"
git remote add origin https://github.com/<usuario>/<repo>.git
git push -u origin main
```
`mlflow.db` (creado por `make first-run`) **sí se versiona**; `mlartifacts/` no.

En GitHub → **Settings → Actions → General → Workflow permissions → "Read and write permissions"**
(necesario para que `retrain.yml` haga commit y dispare `cd.yml`).

## 3. Space de Hugging Face
1. huggingface.co → *New Space* → SDK **Docker** → plantilla *Blank* → visibilidad pública.
   Anota `<HF_USERNAME>` y `<HF_SPACE>` (nombre del Space).
2. huggingface.co/settings/tokens → *New token* → tipo **Write** → copia el token.

## 4. Secrets de GitHub (Settings → Secrets and variables → Actions → *New repository secret*)
| Secret | Valor |
|---|---|
| `HF_TOKEN` | token Write de Hugging Face |
| `HF_USERNAME` | tu usuario (u organización) de HF |
| `HF_SPACE` | nombre del Space |

`GITHUB_TOKEN` lo provee GitHub automáticamente (no se configura).

## 5. Primer despliegue
Pestaña **Actions** → *CD* → **Run workflow** (o haz un push a `main` y espera a que CI termine).
`cd.yml` publica un snapshot ligero en el Space (sin tests/docs/mlflow), HF construye el
Dockerfile y el workflow espera hasta que `/health` responda. URL:
`https://<usuario>-<space>.hf.space` (en minúsculas, `_` → `-`). Verifica `/health`,
`/model-info` y `/docs`.

## 6. Montar la UI del diseñador
1. El diseñador entrega `app/ui.py` (+ assets en `app/`) con la función **`build_ui() -> gr.Blocks`**.
2. Si necesita librerías extra, se añaden **con versión fija** a `requirements-app.txt`.
3. La UI llama a la API por HTTP en `API_BASE_URL` (por defecto `http://127.0.0.1:7860`) usando
   exactamente el contrato de la API (todos los textos visibles en inglés).
4. `main.py` ya hace `gr.mount_gradio_app(app, build_ui(), path="/")`: la UI queda en la raíz y la
   API en `/health`, `/model-info`, `/predict`, `/latest`, `/docs`.
5. Prueba local: `make serve` → http://localhost:7860. Prueba Docker: `docker compose up --build`.
6. `git add app requirements-app.txt && git commit && git push` → CI → CD redespliega solo.
Si la UI falla al cargar, `main.py` lo registra en logs y la API sigue sirviendo.

## 7. Verificación final (checklist)
- [ ] CI verde en `main` (lint, 58 pruebas, build Docker).
- [ ] CD verde y Space en estado *Running*.
- [ ] `/model-info` muestra `version`, métricas y rango de datos reales.
- [ ] `/latest` devuelve datos recientes de Puno.
- [ ] `retrain.yml` ejecutado manualmente al menos una vez (Actions → Retrain → Run workflow).
