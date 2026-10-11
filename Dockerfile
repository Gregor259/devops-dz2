# Образ приложения в один этап — отправная точка домашнего задания.
# python:3.11-alpine заменить базовым образом своего варианта.
# В таком виде сборка падает: драйверы баз компилируются из исходников,
# а компилятора и заголовков в образе нет. Задание — переписать файл в два этапа.
FROM python:3.11-alpine AS build

RUN apk add --no-cache build-base postgresql-dev mariadb-connector-c-dev pkgconf

RUN python -m venv /venv
WORKDIR /app
COPY requirements.txt .
RUN /venv/bin/pip install --no-cache-dir -r requirements.txt

FROM python:3.11-alpine

RUN apk add --no-cache libpq mariadb-connector-c

COPY --from=build /venv /venv
ENV PATH="/venv/bin:$PATH"
ENV PYTHONDONTWRITEBYTECODE=1

WORKDIR /app
COPY app.py .

ARG VERSION=5.0
RUN echo "$VERSION" > /app/VERSION

STOPSIGNAL SIGINT
CMD ["python", "app.py"]
