# Runbook operativo

| Símbolo | Significado |
|---|---|
| 🔎 | cómo detectarlo |
| 🛠️ | qué hacer |
| ↩️ | cómo revertir |

## 1. Falla de ingesta
**Síntomas**: `retrain.yml` termina con `INGEST REJECTED (invalid data)` (exit 2) o `INGEST FAILED (API)` (exit 3); o el log dice `[fallback] Open-Meteo unavailable...`.
- **API caída / timeout (modo `fallback`)** 🔎 log `status=fallback`. 🛠️ El retrain continúa con el dataset versionado (no falla). Reintentar con *Run workflow* más tarde. Si se exige datos frescos: `python -m aqi.ingest --strict`.
- **Datos inválidos (pandera)** 🔎 mensaje con tabla `failure_cases` (columna, check, valor). 🛠️ Nada se escribe en `data/processed`. Revisar si Open-Meteo cambió unidades/variables (`aqi/download.py::AIR_VARS/WEATHER_VARS`) o si es un valor aislado; ajustar rangos en `aqi/schemas.py` solo si el valor es físicamente posible.
- **Dataset corrupto** ↩️ `git checkout -- data/processed/dataset.parquet` o reconstruir: `python -m aqi.ingest --reset` (parte del bootstrap inmutable `data/raw`).
- **Bootstrap imposible** (API caída el día de la entrega) ↩️ usar el `data/raw/bootstrap.parquet` ya versionado.

## 2. Degradación del modelo
**Síntomas**: CI rojo en `test_champion_reevaluated_on_current_holdout_above_minimum` ("Champion degraded"); F1 macro del champion cae semana a semana en `decisions.jsonl` (`champion_f1_macro`); quejas de la UI.
🛠️ Pasos:
1. `cat models/reports/decisions.jsonl | tail` → tendencia de `champion_f1_macro` y `challenger_f1_macro`.
2. Ver `models/reports/class_distribution.png` (¿cambió el régimen? p. ej. temporada de quemas) y `confusion_challenger.png`.
3. Reentrenar con más búsqueda: *Run workflow* con `n_trials=80`.
4. Si ningún challenger supera al champion pero el champion bajó del mínimo: revisar features/datos (deriva) y, como medida temporal, bajar `quality_gate_f1_macro` **documentando el motivo**.
↩️ Volver al champion anterior: `git revert <commit chore(retrain): promote...>` → push → CI → CD. (La versión previa vuelve a `models/champion/`; en MLflow reasignar el alias: *Models → aqi-category-classifier → versión anterior → Add alias "champion"*.)

## 3. Falla de despliegue
**Síntomas**: `cd.yml` rojo; Space en *Build error* / *Runtime error*; `/health` no responde.
- **`Falta el secret ...`** 🛠️ Configurar `HF_TOKEN`, `HF_USERNAME`, `HF_SPACE` (docs/DEPLOY.md §4).
- **401/403 al hacer push** 🛠️ Token expirado o sin permiso *Write*: generar uno nuevo y actualizar el secret.
- **Build error en HF** 🔎 pestaña *Logs → Build*. Causas típicas: dependencia sin versión fija, falta `models/champion` (¿se versionó?), archivo >10 MB sin LFS. 🛠️ Reproducir en local: `docker build -t aqi-app . && docker run -p 7860:7860 aqi-app`.
- **Runtime error / UI no carga** 🔎 *Logs → Container*. `main.py` mantiene la API viva aunque falle la UI (`UI could not be mounted`): corregir `app/ui.py` y hacer push.
- **`/health` ok pero `/model-info` 503** 🛠️ Falta `models/champion/model.joblib` o `metadata.json` en la imagen.
- **`/latest` 503** 🛠️ Open-Meteo no responde y no hay `last_window.parquet`; la API ya intenta ese respaldo automáticamente.
↩️ Rollback: `git revert <commit>` y push (CD redespliega), o *Actions → CD → Run workflow* sobre un commit estable. En HF también puede restaurarse un commit anterior desde la pestaña *Files → History*.

## 4. Mantenimiento rutinario
- Semanal (automático): `retrain.yml` (lunes 06:00 UTC).
- Mensual: revisar `decisions.jsonl`, deriva de clases y tamaño del repo (`mlflow.db`, `data/processed`).
- Rotar `HF_TOKEN` cada 90 días.
