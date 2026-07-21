FROM python:3.12.11-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
RUN groupadd --system discovery && useradd --system --gid discovery --home-dir /nonexistent discovery \
    && mkdir /app/var && chown discovery:discovery /app/var
COPY --chown=discovery:discovery discovery/ /app/discovery/
COPY --chown=discovery:discovery pyproject.toml /app/
USER discovery
EXPOSE 8080
CMD ["python", "-m", "discovery", "serve"]

