


```shell
# 创建命名空间
kubectl create namespace dinky
# 为命名空间创建权限
kubectl create clusterrolebinding flink-role-binding-default --clusterrole=edit --serviceaccount=dinky:default
```

```docker
ARG FLINK_VERSION=1.16.3   # flink 版本号

FROM flink:${FLINK_VERSION}-scala_2.12 # flink官方镜像tag

ADD extends /opt/flink/lib # 把当前extends目录下的jar添加进依赖目录

RUN rm -rf ${FLINK_HOME}/lib/flink-table-planner-loader-*.jar # 删除loader包，替换为不带loader的


wget  https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u191-b12/OpenJDK8U-jdk_aarch64_linux_hotspot_8u252b09.tar.gz
tar -zxf OpenJDK8U-jdk_aarch64_linux_hotspot_8u252b09.tar.gz
mv jdk8u191-b12 /opt/tools/installed/
```