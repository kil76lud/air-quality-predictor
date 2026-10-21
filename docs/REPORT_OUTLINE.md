# Esquema del informe técnico (para un equipo de TI) — 8 pts

Extensión sugerida: 10-14 páginas. Cada criterio de la rúbrica tiene su capítulo; las figuras
salen de `models/reports/` y de MLflow.

## Portada y resumen ejecutivo (½ pág.)
Problema, solución, resultado clave (F1 macro del champion, URL del Space, repo).

## 1. Herramientas y plataformas (2 pts)
Tabla *herramienta → para qué → por qué esta y no otra → costo (todas gratuitas)*:
Open-Meteo (datos sin API key; **limitación: reanálisis CAMS por cuadrícula, no sensores locales**),
pandas/pyarrow (datos), **pandera** (validación), scikit-learn/**XGBoost** (modelo), **Optuna**
(hiperparámetros), **MLflow** (tracking + Model Registry con alias `champion`, SQLite),
**FastAPI** + **Gradio** (API/UI), pytest + ruff (calidad), **Docker**, **GitHub Actions**
(CI/CD), **Hugging Face Spaces** (hosting; alternativa evaluada: Render, descartado por *cold
starts* y despliegue por webhook).
Incluir: diagrama de arquitectura (Open-Meteo → ingesta+pandera → features → entrenamiento →
champion/challenger → `models/champion` → Docker → HF Space ← usuario) y las **limitaciones**
(cuadrícula, ciudad única, 12 meses, clases raras en Puno, modo manual con lags aproximados).

## 2. Organización del código (2 pts)
Árbol del repo (README) y responsabilidades por módulo (`aqi/*`), separación **UI (`app/`) ↔
ML (`aqi/`)** con la API como contrato único, `config/config.yaml` como fuente de
configuración, convenciones (tipado, docstrings, ruff), un test por módulo, datos y modelo
versionados en git (trazabilidad commit ↔ despliegue).
Sección propia **Prevención de data leakage**: definición del target (`us_aqi.shift(-6)`),
features solo ≤ t, `us_aqi` excluida, malla horaria regular (los huecos no desplazan lags), split
cronológico con hueco, `TimeSeriesSplit(gap=6)`, y las 5 pruebas de `test_no_leakage.py`.
Sección **Modelo y resultados**: distribución de clases, baseline (RF) vs optimizado (XGBoost+Optuna),
historial de Optuna, importancia de features, matriz de confusión, F1 por clase, manejo de
desbalance (class weights), criterio de F1 macro sobre clases presentes.

## 3. Consideraciones del despliegue inicial (2 pts)
- Estrategia de datos: bootstrap de 12 meses versionado como respaldo si la API falla.
- Imagen Docker ligera (solo runtime), usuario no root (UID 1000 requerido por HF), `HEALTHCHECK`, puerto 7860.
- Secrets (`HF_TOKEN`, `HF_USERNAME`, `HF_SPACE`) y permisos de Actions.
- Snapshot ligero hacia el Space (commit huérfano sin tests/docs/mlflow).
- Montaje de la UI (`gr.mount_gradio_app`) y tolerancia a fallos de la UI.
- Riesgos y mitigaciones: API externa caída, límites de HF gratuito (suspensión por inactividad), tamaño de archivos (<10 MB sin LFS), rutas absolutas de MLflow (normalizadas en `_setup_mlflow`).
- Pasos de despliegue inicial: `docs/DEPLOY.md`.

## 4. Flujos de mantenimiento e integración continua (2 pts)
- **CI** (`ci.yml`): ruff → pytest (ingesta, features, no-leakage, API, champion, quality gate de F1 macro) → build Docker + smoke test.
- **Retrain** (`retrain.yml`, cron semanal + manual): ingesta+pandera → challenger → comparación → promoción → commit → disparo de CD. Diagrama de flujo y tabla de entradas manuales (`n_trials`, `seed`, `min_delta`).
- **Champion/challenger**: mismo test, umbral +0.005 de F1 macro, bitácora `decisions.jsonl`, tags y alias en el Registry.
- **CD** (`cd.yml`): tras CI verde en `main` → redeploy → verificación de `/health`.
- Nota técnica: los pushes con `GITHUB_TOKEN` no disparan otros workflows → `gh workflow run cd.yml`.
- **Runbook** (anexo A): falla de ingesta, degradación del modelo, falla de despliegue → `docs/RUNBOOK.md`.
- Evidencias: capturas de Actions (verde/rojo), MLflow, `/model-info` antes/después de una promoción.

## Anexos
A. Runbook · B. Contrato de la API · C. Ejemplo de ejecución de `retrain.yml` · D. Resultados completos (JSON de `last_run.json`) · E. Referencias (Open-Meteo/CAMS: atribución y licencia).
