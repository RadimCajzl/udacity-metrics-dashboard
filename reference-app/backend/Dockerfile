FROM python:3.10-alpine

ENV APP_HOME /app
WORKDIR $APP_HOME

RUN python -m pip install poetry
COPY pyproject.toml poetry.lock ./
RUN poetry install --only main

COPY . ./

ARG PROJECT_ID
ENV PROJECT_ID ${PROJECT_ID}

EXPOSE 8081

CMD ["poetry", "run", "gunicorn", "--access-logfile", "-", "--error-logfile", "-", "-w", "4", "-b", "0.0.0.0:8081", "app:app"]
