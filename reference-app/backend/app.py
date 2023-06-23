from flask import Flask, jsonify, request
from flask_pymongo import PyMongo
from prometheus_flask_exporter import PrometheusMetrics
from telemetry import trace, tracer, tracing_provider
from opentelemetry.instrumentation.flask import FlaskInstrumentor

app = Flask(__name__)

app.config["MONGO_DBNAME"] = "example-mongodb"
app.config[
    "MONGO_URI"
] = "mongodb://example-mongodb-svc.default.svc.cluster.local:27017/example-mongodb"
metrics = PrometheusMetrics(app, default_labels={"app": "frontend"})

FlaskInstrumentor().instrument_app(app=app, tracer_provider=tracing_provider)

mongo = PyMongo(app)

## Telemetry inspired by CNCF blog: https://www.cncf.io/blog/2022/04/22/opentelemetry-and-python-a-complete-instrumentation-guide/


@app.route("/")
def homepage():
    return "Hello World"


@app.route("/api")
def my_api():
    with tracer.start_as_current_span("my_span", attributes={"endpoint": "/api"}):
        # Remark: adding new span manually is redundant, because the span
        # is created automatically using FlaskInstrumentor. Included just
        # "to show off" I learned how to create my own spans.
        answer = "something"
        trace.get_current_span().add_event("log", {"api.response": "something"})
        return jsonify(repsonse=answer)


@app.route("/star", methods=["POST"])
def add_star():
    star = mongo.db.stars
    name = request.json["name"]
    distance = request.json["distance"]
    trace.get_current_span().add_event(
        "log", {"star.name": name, "star.distance": distance}
    )
    star_id = star.insert_one({"name": name, "distance": distance})
    new_star = star.find_one({"_id": star_id})
    output = {"name": new_star["name"], "distance": new_star["distance"]}
    return jsonify({"result": output})


if __name__ == "__main__":
    app.run()
