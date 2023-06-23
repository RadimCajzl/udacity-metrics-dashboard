all: kind-init kind-jaeger kind-apps kind-prometheus kind-apps-traffic

kind-init:
	kind create cluster --name kind --config=kind/config.yaml
	
	# update ca-certificates (we mounted /usr/local/share/ca-certificates/ from host,
	# now we need to instruct all nodes to use it:
	# (Required for ZScaler if we want to pull public images to kind.)
	docker exec -it kind-control-plane update-ca-certificates 
	docker exec -it kind-worker update-ca-certificates

	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.0.3/deploy/static/provider/cloud/deploy.yaml
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.6.3/cert-manager.yaml

	kubectl wait deployment cert-manager-webhook -n cert-manager --for condition=Available=True --timeout=900s
	kubectl wait deployment ingress-nginx-controller -n ingress-nginx --for condition=Available=True --timeout=900s


kind-clean:
	kind delete cluster --name kind

helm-repos:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo add stable https://charts.helm.sh/stable
	helm repo update

kube-events:
	kubectl get events --all-namespaces --sort-by='.lastTimestamp'

kind-prometheus: kind-prometheus-clean
	kubectl create namespace monitoring

	kubectl create secret generic additional-scrape-configs \
		--from-file=manifests/prometheus-config/app-metrics-scraping.yaml -n monitoring

	helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring \
		--set prometheus.prometheusSpec.additionalScrapeConfigsSecret.enabled=true \
		--set prometheus.prometheusSpec.additionalScrapeConfigsSecret.name=additional-scrape-configs \
		--set prometheus.prometheusSpec.additionalScrapeConfigsSecret.key=app-metrics-scraping.yaml

	kubectl wait deployment prometheus-grafana -n monitoring --for condition=Available=True --timeout=900s
	kubectl port-forward -n monitoring $$(kubectl get pod -n monitoring | grep grafana | awk '{print $$1}') 3000 &
	kubectl port-forward -n monitoring service/prometheus-kube-prometheus-prometheus 9090:9090 &

kind-prometheus-clean:
	kubectl delete namespace monitoring --ignore-not-found=true

	# break port-forwarding:
	curl localhost:3000 || echo Port-forwarding to Grafana stopped.
	curl localhost:9090 || echo Port-forwarding to Prometheus operator stopped.

kind-jaeger:
	kubectl create namespace observability
	kubectl create -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.45.0/jaeger-operator.yaml -n observability
	# kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/${jaeger_version}/deploy/cluster_role.yaml
	# kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/${jaeger_version}/deploy/cluster_role_binding.yaml
	kubectl wait deployment jaeger-operator -n observability --for condition=Available=True --timeout=900s

kind-jaeger-clean:
	kubectl delete namespace observability --ignore-not-found=true

kind-apps: kind-apps-clean
	cd reference-app/backend && make docker-build
	cd reference-app/frontend && make docker-build
	kind load docker-image radimcajzl/udacity-metrics-backend:latest
	kind load docker-image radimcajzl/udacity-metrics-frontend:latest
	kubectl apply -f manifests/app
	kubectl wait deployment frontend-app -n default --for condition=Available=True --timeout=900s

	kubectl wait deployment jaeger-app -n default --for condition=Available=True --timeout=900s
	kubectl port-forward -n default service/jaeger-app-query 16686:16686 &

kind-apps-clean:
	kubectl delete deployment/backend-app --ignore-not-found=true
	kubectl delete service/backend-service --ignore-not-found=true
	kubectl delete deployment/frontend-app --ignore-not-found=true
	kubectl delete service/frontend-service --ignore-not-found=true

	kubectl delete jaeger/jaeger-app --ignore-not-found=true
	kubectl delete deployment/jaeger-app --ignore-not-found=true
	kubectl delete service/jaeger-app-agent --ignore-not-found=true
	kubectl delete service/jaeger-app-collector --ignore-not-found=true
	kubectl delete service/jaeger-app-collector-headless --ignore-not-found=true
	kubectl delete service/jaeger-app-query --ignore-not-found=true

	# break port-forwarding:
	curl localhost:16686 || echo Port-forwarding to Jaeger stopped.
	
kind-apps-traffic:
	## normal traffic:
	# Frontend:
	for idx in `seq 1 1000`; do curl http://localhost:31080/ > /dev/null 2> /dev/null & done
	# Backend:
	for idx in `seq 1 1000`; do curl http://localhost:31081/api > /dev/null 2> /dev/null &  done
	
	## errors traffic:
	# Frontend:
	for idx in `seq 1 50`; do curl http://localhost:31080/this_does_not_exist > /dev/null 2> /dev/null &  done
	# Backend:
	for idx in `seq 1 42`; do curl http://localhost:31081/neither_does_this > /dev/null 2> /dev/null &  done
	for idx in `seq 1 10`; do curl -X POST http://localhost:31081/star -H "Content-Type: application/json" -d '{"ahoj":"nazdar"}' > /dev/null 2> /dev/null &  done