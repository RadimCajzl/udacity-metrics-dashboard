from flask import Flask, render_template
from prometheus_flask_exporter import PrometheusMetrics
from telemetry import tracing_provider
from opentelemetry.instrumentation.flask import FlaskInstrumentor

app = Flask(__name__)
metrics = PrometheusMetrics(app, default_labels={"app": "frontend"})

FlaskInstrumentor().instrument_app(app=app, tracer_provider=tracing_provider)


@app.route("/")
def homepage():
    return render_template("main.html")


if __name__ == "__main__":
    app.run()
