


```shell
docker network create flink-network
docker run -d --name flink-jm --network flink-network -p 8081:8081 -p 8082:8082 flink:1.16.2-scala_2.12 jobmanager
docker exec -it flink-jm bash

kubectl run flink-jm --image=flink:1.16.2-scala_2.12 jobmanager
kubectl exec -it flink-jm bash

kubectl create namespace flink-test
kubectl create serviceaccount flink-svc-account -n flink-test
kubectl create clusterrolebinding flink-role-binding-flink --clusterrole=edit --serviceaccount=flink-test:flink-svc-account


./bin/flink run-application \
    --target kubernetes-application \
    -Dkubernetes.cluster-id=test-flink-native-k8s-app \
    -Dkubernetes.namespace=flink-test \
    -Dkubernetes.service-account=flink-svc-account \
    -Dkubernetes.container.image=flink:1.16.2-scala_2.12 \
    local:///opt/flink/examples/streaming/TopSpeedWindowing.jar

kubectl port-forward svc/test-flink-native-k8s-app-rest 8081 --address 192.168.3.9 -nflink-test

./bin/flink list \
    --target kubernetes-application \
    -Dkubernetes.cluster-id=test-flink-native-k8s-app \
    -Dkubernetes.namespace=flink-test \
    -Dkubernetes.service-account=flink-svc-account
    
bin/flink list --target kubernetes-application -Dkubernetes.cluster-id=test-flink-native-k8s-app
bin/flink logs --target kubernetes-application -Dkubernetes.cluster-id=test-flink-native-k8s-app
bin/flink cancel --target kubernetes-application -Dkubernetes.cluster-id=test-flink-native-k8s-app

```

```Dockerfile
ARG FLINK_VERSION=1.16.3
FROM flink:${FLINK_VERSION}-scala_2.12
ADD extends /opt/flink/lib
RUN rm -rf ${FLINK_HOME}/lib/flink-table-planner-loader-*.jar
```
```shell
cat > ./Dockerfile << EOF
ARG FLINK_VERSION=1.16.3
FROM flink:${FLINK_VERSION}-scala_2.12
ADD extends /opt/flink/lib
COPY extends/dinky-app-1.16-1.0.2-jar-with-dependencies.jar /opt/flink/
RUN rm -rf ${FLINK_HOME}/lib/flink-table-planner-loader-*.jar
EOF

mkdir extennds
cp lib/commons-cli-1.3.1.jar extends
cp lib/dinky-app-1.16-1.0.2-jar-with-dependencies.jar extends
cp lib/flink-table-planner_2.12-1.16.3.jar extends
docker build -t dinky-flink:1.0.2-1.16.3 . --no-cache
docker tag dinky-flink:1.0.2-1.16.3 registry.cn-hangzhou.aliyuncs.com/tiankx/dinky-flink:1.0.2-1.16.3
docker push registry.cn-hangzhou.aliyuncs.com/tiankx/dinky-flink:1.0.2-1.16.3


docker network create flink-network
docker run -d --name dinky-flink-jm --network flink-network -p 8081:8081 -p 8082:8082 dinky-flink:1.0.2-1.16.3 jobmanager
docker exec -it dinky-flink-jm bash

kubectl create secret docker-registry aliyun-docker-secret \
    --docker-server=registry.cn-hangzhou.aliyuncs.com \
    --docker-username=镜湖遗风 \
    --docker-password=Tt181024 \
    --docker-email=tiankx1003@gmail.com \
    --namespace=dinky

```