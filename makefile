RM=/bin/rm -f
RMD=/bin/rm -Rf
BIN=/usr/local/bin
EHOME=$(shell echo $$HOME | sed -e 's/\//\\\//g')


.install-argo-ci:
	helm repo add argo https://argoproj.github.io/argo-helm/
	helm install argo/argo-ci --name argo-ci

.delete-argo-ci:
	helm del --purge argo-ci

.install-argo-cd:
	kubectl create namespace argocd
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v0.7.1/manifests/install.yaml
	sudo curl -L -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/v0.7.1/argocd-linux-amd64
	sudo chmod +x /usr/local/bin/argocd

.delete-argo-cd:
	-kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v0.7.1/manifests/install.yaml	
	-kubectl delete namespace argocd
	-sudo $(RM) /usr/local/bin/argocd 	

.install-kubernetes-dashboard:
	kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
	kubectl create serviceaccount demo-dashboard-sa
	kubectl create clusterrolebinding demo-dashboard-sa --clusterrole=cluster-admin --serviceaccount=default:demo-dashboard-sa
	

.delete-kubernetes-dashboard:
	kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
	kubectl delete serviceaccount demo-dashboard-sa
	kubectl delete clusterrolebinding demo-dashboard-sa

.install-istio-helm-tiller:
	-${RMD} istio-1.0.0
	curl -L https://git.io/getLatestIstio | ISTIO_VERSION=1.0.0 sh
	sudo cp istio-1.0.0/bin/istioctl ${BIN}/bin
	kubectl create namespace istio-system
	helm install istio-1.0.0/install/kubernetes/helm/istio --debug --timeout 600 --wait --name istio --namespace istio-system --set grafana.enabled=true --set servicegraph.enabled=true --set prometheus.enabled=true --set tracing.enabled=true --set global.configValidation=false 

.delete-istio-helm-tiller:
	-helm del --purge istio
	-kubectl -n istio-system delete job --all
	-kubectl delete -f istio-1.0.0/install/kubernetes/helm/istio/templates/crds.yaml -n istio-system
	-kubectl delete namespace istio-system
	-sudo ${RM} ${BIN}/istioctl

.install-istio-helm-template:
	-${RMD} istio-1.0.0
	curl -L https://git.io/getLatestIstio | ISTIO_VERSION=1.0.0 sh
	sudo cp istio-1.0.0/bin/istioctl ${BIN}/bin
	kubectl create namespace istio-system
	helm template istio-1.0.0/install/kubernetes/helm/istio --name istio --namespace istio-system --set grafana.enabled=true --set servicegraph.enabled=true --set prometheus.enabled=true --set tracing.enabled=true > istio-1.0.0/istio.yaml
	kubectl create -f istio-1.0.0/istio.yaml

.delete-istio-helm-template:
	-kubectl delete -f istio-1.0.0/istio.yaml
	-kubectl -n istio-system delete job --all
	-kubectl delete -f istio-1.0.0/install/kubernetes/helm/istio/templates/crds.yaml -n istio-system
	-kubectl delete namespace istio-system
	-sudo ${RM} ${BIN}/istioctl


.install-helm-bin:
ifeq (,$(wildcard /usr/local/bin/helm))
	curl -L https://storage.googleapis.com/kubernetes-helm/helm-v2.10.0-rc.2-linux-amd64.tar.gz | tar -xzv
	sudo cp linux-amd64/helm /usr/local/bin
	${RMD} linux-amd64
endif
	helm home


.install-helm: .install-helm-bin
	which kubectl
	kubectl version
	kubectl -n kube-system create serviceaccount tiller
	kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
	helm init --service-account=tiller
	-helm repo update

.delete-helm-bin:
	-sudo ${RM} /usr/local/bin/helm

.delete-helm: 
	-helm reset
	-${RMD} ~/.helm
	-kubectl -n kube-system delete deployment tiller-deploy 
	-kubectl delete clusterrolebinding tiller
	-kubectl -n kube-system delete serviceaccount tiller
	-make .delete-helm-bin
	-echo 'helm deleted.'

#for ML model deployment with Seldon	
.install-s2i: .delete-s2i
	mkdir seldon
	curl -L https://github.com/openshift/source-to-image/releases/download/v1.1.10/source-to-image-v1.1.10-27f0729d-linux-amd64.tar.gz | tar -xzv -C seldon
	sudo cp seldon/s2i /usr/local/bin
	$(RMD) seldon
.delete-s2i:
	-$(RM) /usr/local/bin/s2i

.install-seldon-core:
	helm install seldon-core-crd --name seldon-core-crd --repo https://storage.googleapis.com/seldon-charts --set usage_metrics.enabled=true
	helm install seldon-core --name seldon-core --repo https://storage.googleapis.com/seldon-charts --set apife.enabled=true --set rbac.enabled=true --set ambassador.enabled=true

.delete-seldon-core:
	helm del --purge seldon-core-crd
	helm del --purge seldon-core

.install-kubectl:
	curl -Lo kubectl https://storage.googleapis.com/kubernetes-release/release/$$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x kubectl && sudo cp kubectl /usr/local/bin/ && rm kubectl

.delete-kubectl:
	${RM} ${BIN}/kubectl

.install-minikube: .install-kubectl
	mkdir -p ${BIN}
	mkdir -p ~/.kube
	touch ~/.kube/config
	curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube && sudo cp minikube /usr/local/bin/ && rm minikube

.delete-minikube: .delete-kubectl
	sudo kubeadm reset
	${RM} ${BIN}/minikube

.create-minikube-cluster:
	sudo -E CHANGE_MINIKUBE_NONE_USER=true MINIKUBE_WANTREPORTERRORPROMPT=false MINIKUBE_WANTUPDATENOTIFICATION=false ${BIN}/minikube --loglevel 0 start --vm-driver=none --apiserver-ips 127.0.0.1
	sudo cp -R /root/.kube $$HOME/
	sudo chown -R $$USER $$HOME/.kube
	sudo chgrp -R $$USER $$HOME/.kube
	sudo cp  -R /root/.minikube $$HOME/
	sudo chown -R $$USER $$HOME/.minikube
	sudo chgrp -R $$USER $$HOME/.minikube
	sed -i -e 's/\/root/$(EHOME)/g' $$HOME/.kube/config
	

.delete-minikube-cluster:
	-sudo ${BIN}/minikube delete
	-${RMD} ~/.kube
	-${RMD} ~/.minikube

.open-services-node-ports-for-minikube:
	-kubectl -n kube-system patch svc kubernetes-dashboard -p '{"spec":{"type":"NodePort"}}'
	-kubectl -n istio-system patch svc jaeger-query -p '{"spec":{"type":"NodePort"}}'
	-kubectl -n istio-system patch svc grafana -p '{"spec":{"type":"NodePort"}}'
	-kubectl -n istio-system patch svc prometheus -p '{"spec":{"type":"NodePort"}}'
	-kubectl -n istio-system patch svc servicegraph -p '{"spec":{"type":"NodePort"}}'
	-kubectl -n hello-t1 patch svc hello -p '{"spec":{"type":"NodePort"}}'
