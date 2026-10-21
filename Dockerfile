# Imagen de runtime: solo app + modelo champion (sin Optuna/MLflow) -> build rápido
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# libgomp1: requerido por XGBoost; curl: para el HEALTHCHECK
RUN apt-get update && apt-get install -y --no-install-recommends libgomp1 curl \
    && rm -rf /var/lib/apt/lists/*

# Hugging Face Spaces ejecuta el contenedor como usuario 1000
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user PATH=/home/user/.local/bin:$PATH
WORKDIR /home/user/app

# Capa de dependencias primero (se cachea mientras no cambie requirements-app.txt)
COPY --chown=user requirements-app.txt .
RUN pip install --user -r requirements-app.txt

# Código y modelo champion
COPY --chown=user config ./config
COPY --chown=user aqi ./aqi
COPY --chown=user app ./app
COPY --chown=user models/champion ./models/champion
COPY --chown=user main.py .

# HF Spaces espera el puerto 7860 (definido también en README.md: app_port: 7860)
EXPOSE 7860
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fs http://localhost:${PORT:-10000}/health || exit 1

# Cambia esta línea:
# CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7860"]

# Por esta otra:
CMD sh -c "uvicorn main:app --host 0.0.0.0 --port ${PORT:-10000}"
