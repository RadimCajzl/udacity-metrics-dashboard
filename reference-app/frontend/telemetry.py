## Inspired by
# - CNCF blog: https://www.cncf.io/blog/2022/04/22/opentelemetry-and-python-a-complete-instrumentation-guide/
# - OpenTelemetry documentation: https://opentelemetry-python.readthedocs.io/en/latest/exporter/jaeger/jaeger.html

import os
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.trace.export import ConsoleSpanExporter
from opentelemetry.exporter.jaeger.thrift import JaegerExporter


tracing_provider = TracerProvider(
    resource=Resource.create(
        {"service.name": "frontend", "service.organization": "udacity"}
    )
)
console_tracing_processor = BatchSpanProcessor(ConsoleSpanExporter())
jaeger_tracing_processor = BatchSpanProcessor(
    JaegerExporter(
        agent_host_name=os.environ["JAEGER_HOST"],
        agent_port=int(os.environ["JAEGER_PORT"]),
    )
)
tracing_provider.add_span_processor(console_tracing_processor)
tracing_provider.add_span_processor(jaeger_tracing_processor)
trace.set_tracer_provider(tracing_provider)
tracer = trace.get_tracer("frontend_app")
