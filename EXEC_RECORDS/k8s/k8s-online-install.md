# k8s & container install

## system configuration

```bash
python -m SimpleHTTPServer 9999

hostnamectl set-hostname xxx
hostnamectl set-hostname xxx
cat > /etc/hosts << EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
10.1.1.10   xxx
10.1.1.11   xxx
EOF
```

## required configuration

```bash
# 关闭swap
swapoff -a
sed -ri 's/.*swap.*/#&/' /etc/fstab
cat > /etc/sysctl.conf << EOF
vm.swappiness=0
EOF
# 生效
sysctl -p
free -m
# 网桥设置
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system
modprobe br_netfilter
modprobe overlay
lsmod | grep -e br_netfilter -e overlay
# ipvs设置
yum install ipset ipvsadm -y
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF
chmod +x /etc/sysconfig/modules/ipvs.modules
/bin/bash /etc/sysconfig/modules/ipvs.modules
lsmod | grep -e ip_vs -e nf_conntrack_ipv4
# 关闭防火墙
iptables -F
iptables -X
# 禁用selinux
getenforce
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/g' /etc/selinux/config
```

## containerd install

[official doc](https://github.com/containerd/containerd/blob/main/docs/getting-started.md)

```bash
# 下载离线安装包
$ yumdownloader --destdir=./containers/images containerd.io-1.6.9-3.1.el7.x86_64
# 安装离线安装包
$ yum -y install ./containers/*.rpm
# start containerd
$ systemctl daemon-reload
$ systemctl enable containerd --now 
Created symlink from /etc/systemd/system/multi-user.target.wants/containerd.service to /etc/systemd/system/containerd.service.

$ mkdir /data/containerd
# configration it
$ containerd config default | tee /etc/containerd/config.toml
$ vi /etc/containerd/config.toml
# 在默认配置中，需要修改的内容如下
# 存储目录
root = "/data/containerd"
# 如果网络不同, 可以修改镜像源
sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.2"
# 加上默认配置
[plugins."io.containerd.grpc.v1.cri".registry]
      config_path = "/etc/containerd/certs.d"
# 对接 harbor 
     [plugins."io.containerd.grpc.v1.cri".registry.configs]
        ## 配置对接 harbor
        [plugins."io.containerd.grpc.v1.cri".registry.configs."harbor.lsym.cn".auth]  ## harbor 域名(ip+port)
         username = "admin"  # harbor 用户名
         password = "DaAs@_2023Hb"  # harbor 密码
         
# 看 harbor 中: make container able to pull, 给containerd增加证书         

$ sudo cat > /etc/containerd/config.toml << EOF
disabled_plugins = []
imports = []
oom_score = 0
plugin_dir = ""
required_plugins = []
root = "/var/lib/containerd"
state = "/run/containerd"
temp = ""
version = 2

[cgroup]
 path = ""

[debug]
 address = ""
 format = ""
 gid = 0
 level = ""
 uid = 0

[grpc]
 address = "/run/containerd/containerd.sock"
 gid = 0
 max_recv_message_size = 16777216
 max_send_message_size = 16777216
 tcp_address = ""
 tcp_tls_ca = ""
 tcp_tls_cert = ""
 tcp_tls_key = ""
 uid = 0

[metrics]
 address = ""
 grpc_histogram = false

[plugins]

 [plugins."io.containerd.gc.v1.scheduler"]
   deletion_threshold = 0
   mutation_threshold = 100
   pause_threshold = 0.02
   schedule_delay = "0s"
   startup_delay = "100ms"

 [plugins."io.containerd.grpc.v1.cri"]
   device_ownership_from_security_context = false
   disable_apparmor = false
   disable_cgroup = false
   disable_hugetlb_controller = true
   disable_proc_mount = false
   disable_tcp_service = true
   enable_selinux = false
   enable_tls_streaming = false
   enable_unprivileged_icmp = false
   enable_unprivileged_ports = false
   ignore_image_defined_volumes = false
   max_concurrent_downloads = 3
   max_container_log_line_size = 16384
   netns_mounts_under_state_dir = false
   restrict_oom_score_adj = false
   sandbox_image = "k8s.gcr.io/pause:3.6"
   # sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.2"
   selinux_category_range = 1024
   stats_collect_period = 10
   stream_idle_timeout = "4h0m0s"
   stream_server_address = "127.0.0.1"
   stream_server_port = "0"
   systemd_cgroup = false
   tolerate_missing_hugetlb_controller = true
   unset_seccomp_profile = ""

   [plugins."io.containerd.grpc.v1.cri".cni]
     bin_dir = "/opt/cni/bin"
     conf_dir = "/etc/cni/net.d"
     conf_template = ""
     ip_pref = ""
     max_conf_num = 1

   [plugins."io.containerd.grpc.v1.cri".containerd]
     default_runtime_name = "runc"
     disable_snapshot_annotations = true
     discard_unpacked_layers = false
     ignore_rdt_not_enabled_errors = false
     no_pivot = false
     snapshotter = "overlayfs"

     [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime]
       base_runtime_spec = ""
       cni_conf_dir = ""
       cni_max_conf_num = 0
       container_annotations = []
       pod_annotations = []
       privileged_without_host_devices = false
       runtime_engine = ""
       runtime_path = ""
       runtime_root = ""
       runtime_type = ""

       [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime.options]

     [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]

       [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
         base_runtime_spec = ""
         cni_conf_dir = ""
         cni_max_conf_num = 0
         container_annotations = []
         pod_annotations = []
         privileged_without_host_devices = false
         runtime_engine = ""
         runtime_path = ""
         runtime_root = ""
         runtime_type = "io.containerd.runc.v2"

         [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
           BinaryName = ""
           CriuImagePath = ""
           CriuPath = ""
           CriuWorkPath = ""
           IoGid = 0
           IoUid = 0
           NoNewKeyring = false
           NoPivotRoot = false
           Root = ""
           ShimCgroup = ""
           SystemdCgroup = false

     [plugins."io.containerd.grpc.v1.cri".containerd.untrusted_workload_runtime]
       base_runtime_spec = ""
       cni_conf_dir = ""
       cni_max_conf_num = 0
       container_annotations = []
       pod_annotations = []
       privileged_without_host_devices = false
       runtime_engine = ""
       runtime_path = ""
       runtime_root = ""
       runtime_type = ""

       [plugins."io.containerd.grpc.v1.cri".containerd.untrusted_workload_runtime.options]

   [plugins."io.containerd.grpc.v1.cri".image_decryption]
     key_model = "node"

 	 [plugins."io.containerd.grpc.v1.cri".registry]
     config_path = "/etc/containerd/certs.d"

     [plugins."io.containerd.grpc.v1.cri".registry.auths]

     [plugins."io.containerd.grpc.v1.cri".registry.configs]
        ## 配置对接 harbor
        [plugins."io.containerd.grpc.v1.cri".registry.configs."harbor.daas.com".auth]  ## harbor 域名(ip+port)
         username = "admin"
         password = "DaAs@_2023Hb"

     [plugins."io.containerd.grpc.v1.cri".registry.headers]

   [plugins."io.containerd.grpc.v1.cri".x509_key_pair_streaming]
     tls_cert_file = ""
     tls_key_file = ""

 [plugins."io.containerd.internal.v1.opt"]
   path = "/opt/containerd"

 [plugins."io.containerd.internal.v1.restart"]
   interval = "10s"

 [plugins."io.containerd.internal.v1.tracing"]
   sampling_ratio = 1.0
   service_name = "containerd"

 [plugins."io.containerd.metadata.v1.bolt"]
   content_sharing_policy = "shared"

 [plugins."io.containerd.monitor.v1.cgroups"]
   no_prometheus = false

 [plugins."io.containerd.runtime.v1.linux"]
   no_shim = false
   runtime = "runc"
   runtime_root = ""
   shim = "containerd-shim"
   shim_debug = false

 [plugins."io.containerd.runtime.v2.task"]
   platforms = ["linux/amd64"]
   sched_core = false

 [plugins."io.containerd.service.v1.diff-service"]
   default = ["walking"]

 [plugins."io.containerd.service.v1.tasks-service"]
   rdt_config_file = ""

 [plugins."io.containerd.snapshotter.v1.aufs"]
   root_path = ""

 [plugins."io.containerd.snapshotter.v1.btrfs"]
   root_path = ""

 [plugins."io.containerd.snapshotter.v1.devmapper"]
   async_remove = false
   base_image_size = ""
   discard_blocks = false
   fs_options = ""
   fs_type = ""
   pool_name = ""
   root_path = ""

 [plugins."io.containerd.snapshotter.v1.native"]
   root_path = ""

 [plugins."io.containerd.snapshotter.v1.overlayfs"]
   root_path = ""
   upperdir_label = false

 [plugins."io.containerd.snapshotter.v1.zfs"]
   root_path = ""

 [plugins."io.containerd.tracing.processor.v1.otlp"]
   endpoint = ""
   insecure = false
   protocol = ""

[proxy_plugins]

[stream_processors]

 [stream_processors."io.containerd.ocicrypt.decoder.v1.tar"]
   accepts = ["application/vnd.oci.image.layer.v1.tar+encrypted"]
   args = ["--decryption-keys-path", "/etc/containerd/ocicrypt/keys"]
   env = ["OCICRYPT_KEYPROVIDER_CONFIG=/etc/containerd/ocicrypt/ocicrypt_keyprovider.conf"]
   path = "ctd-decoder"
   returns = "application/vnd.oci.image.layer.v1.tar"

 [stream_processors."io.containerd.ocicrypt.decoder.v1.tar.gzip"]
   accepts = ["application/vnd.oci.image.layer.v1.tar+gzip+encrypted"]
   args = ["--decryption-keys-path", "/etc/containerd/ocicrypt/keys"]
   env = ["OCICRYPT_KEYPROVIDER_CONFIG=/etc/containerd/ocicrypt/ocicrypt_keyprovider.conf"]
   path = "ctd-decoder"
   returns = "application/vnd.oci.image.layer.v1.tar+gzip"

[timeouts]
 "io.containerd.timeout.bolt.open" = "0s"
 "io.containerd.timeout.shim.cleanup" = "5s"
 "io.containerd.timeout.shim.load" = "5s"
 "io.containerd.timeout.shim.shutdown" = "3s"
 "io.containerd.timeout.task.state" = "2s"

[ttrpc]
 address = ""
 gid = 0
 uid = 0
EOF

# restart containerd
$ systemctl daemon-reload
$ systemctl restart containerd
```

### optional servers

[nerdctl official doc](https://github.com/containerd/nerdctl)

```bash
$ wget https://github.com/containerd/nerdctl/releases/download/v0.6.1/nerdctl-0.6.1-linux-amd64.tar.gz
$ mkdir nerdctl
$ tar -zxvf nerdctl-0.6.1-linux-amd64.tar.gz -C nerdctl
nerdctl
containerd-rootless-setuptool.sh
containerd-rootless.sh
$ cp -a nerdctl/nerdctl /usr/bin
$ nerdctl images
REPOSITORY    TAG    IMAGE ID    CREATED    SIZE
```

[crictl official doc](https://github.com/kubernetes-sigs/cri-tools)

```bash
# download the package 
$ wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.24.0/crictl-v1.24.0-linux-amd64.tar.gz
$ tar -zxvf crictl-v1.24.0-linux-amd64.tar.gz -C /usr/local/bin
crictl
# configration it
$ cat > /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 10
debug: false
pull-image-on-create: false
EOF
$ systemctl daemon-reload
# use ctictl
$ crictl images
IMAGE               TAG                 IMAGE ID            SIZE
```

### containerd uninstall 

```bash
systemctl stop containerd
yum -y remove containerd
rm -rf /etc/containerd/
rm -rf /usr/local/lib/systemd/system/containerd.service
rm -rf /usr/local/sbin/runc
rm -rf /opt/containerd/
rm -rf /opt/cni/bin/
rm -rf /usr/bin/ctr
rm -rf /var/run/containerd/
```

## kubectl kubelet kubeadm

### 在线安装

```bash
## 在线安装
yum install -y wget && wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
yum install  kubectl kubelet kubeadm -y
systemctl start kubelet.service
systemctl enable kubelet.service
```

### 离线安装

#### 下载镜像和rpm安装包

```bash
# 离线安装, 查看安装包的k8s集群的镜像版本: kubeadm config images list
# 下载镜像
$ vim download-images.sh
#!/bin/bash
images=(
  k8s.gcr.io/kube-apiserver:v1.21.9
  k8s.gcr.io/kube-controller-manager:v1.21.9
  k8s.gcr.io/kube-scheduler:v1.21.9
  k8s.gcr.io/kube-proxy:v1.21.9
  k8s.gcr.io/pause:3.4.1
  k8s.gcr.io/etcd:3.4.13-0
  k8s.gcr.io/coredns/coredns:v1.8.0
  docker.io/flannel/flannel-cni-plugin:v1.2.0
  docker.io/flannel/flannel:v0.22.3
  registry.k8s.io/ingress-nginx/controller:v1.3.1
  registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.3.0
)
for imageName in ${images[@]} ; do
  docker pull $imageName
  result=$(echo "$imageName" | awk -F ':' '{print $1}' | awk -F '/' '{print $NF}')
  docker save -o ${result}.img $imageName
done
$ sh download-images.sh

# 下载离线安装包
# 1. create repo 
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
yum clean all && yum makecache
# 2. list all the avaliable package
yum list kubelet --showduplicates | sort -r
# 3. download the package
$ yumdownloader --destdir=./k8s/images kubelet-1.21.9 kubeadm-1.21.9 kubectl-1.21.9 kubernetes-cni-1.2.0 cri-tools-1.19.0
```

#### 导入镜像和rpm安装

```bash
# 导入镜像
$ vim install.sh 
#!/bin/bash
images=(
kube-apiserver.img
kube-controller-manager.img
kube-scheduler.img
kube-proxy.img
pause.img
etcd.img
coredns.img
flannel-cni-plugin.img
flannel.img
controller.img
kube-webhook-certgen.img
)
for imageName in ${images[@]} ; do
  ctr -n k8s.io images import /data/package/images/k8s/$imageName
done
$ sh install.sh 

# install
yum remove -y cri-tools kubeadm kubectl kubelet kubernetes-cni
cd rpm/k8s
yum -y install *.rpm
```

#### 修改 kubeadm 文件

```bash
# 通过kubeadm生成默认config文件
kubeadm config print init-defaults --kubeconfig ClusterConfiguration > kubeadm.yml
# 修改配置文件
# 1）修改 criSocket：默认使用docker做为runtime，修改为containerd.sock，使用containerd做为runtime
# 2）修改imageRepository，改为aliyun的镜像仓库地址
# 3）修改podSubnet以及serviceSubnet，根据的自己的环境进行设置
# 4）设置cgroupDriver为systemd，非必要
# 5）修改advertiseAddress为正确ip地址或者0.0.0.0

# 修改后的配置文件
apiVersion: kubeadm.k8s.io/v1beta2
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 0.0.0.0
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock  ## 修改容器运行时
  name: kino1
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
---
apiServer:
  certSANs: ## 修改 ip 和 主机名
  - "192.168.1.247"
  - "kino1"
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
controlPlaneEndpoint: 10.133.59.113:6443 ## 修改
dns:
  type: CoreDNS
etcd:
  local:
    dataDir: /var/lib/etcd  ## etcd 目录
imageRepository: k8s.gcr.io
kind: ClusterConfiguration
kubernetesVersion: 1.21.9   ## k8s 版本
networking:
  dnsDomain: cluster.local
  podSubnet: 10.10.0.0/16
  serviceSubnet: 10.96.0.0/12  ## 注意这个参数要存在
scheduler: {}
```

#### 初始化集群

```bash
$ kubeadm reset -f
$ kubeadm init --config=kubeadm.yml --upload-certs --ignore-preflight-errors=ImagePull
[init] Using Kubernetes version: v1.21.9
[preflight] Running pre-flight checks
	[WARNING Service-Kubelet]: kubelet service is not enabled, please run 'systemctl enable kubelet.service'
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
	[WARNING ImagePull]: failed to pull image k8s.gcr.io/pause:3.4.1: output: time="2023-10-31T12:08:46+08:00" level=fatal msg="pulling image: rpc error: code = Unknown desc = failed to pull and unpack image \"k8s.gcr.io/pause:3.4.1\": failed to resolve reference \"k8s.gcr.io/pause:3.4.1\": failed to do request: Head \"https://k8s.gcr.io/v2/pause/manifests/3.4.1\": dial tcp 64.233.189.82:443: connect: connection timed out"
, error: exit status 1
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local prod.ds.idas03.idc] and IPs [10.96.0.1 172.22.0.41]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [localhost prod.ds.idas03.idc] and IPs [172.22.0.41 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [localhost prod.ds.idas03.idc] and IPs [172.22.0.41 127.0.0.1 ::1]
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "sa" key and public key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "kubelet.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Starting the kubelet
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
[apiclient] All control plane components are healthy after 18.003171 seconds
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config-1.21" in namespace kube-system with the configuration for the kubelets in the cluster
[upload-certs] Storing the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
[upload-certs] Using certificate key:
0d31c051adacd8aa665130083efd0d5e5783c50eb2eeace8549abf9e05beeee5
[mark-control-plane] Marking the node prod.ds.idas03.idc as control-plane by adding the labels: [node-role.kubernetes.io/master(deprecated) node-role.kubernetes.io/control-plane node.kubernetes.io/exclude-from-external-load-balancers]
[mark-control-plane] Marking the node prod.ds.idas03.idc as control-plane by adding the taints [node-role.kubernetes.io/master:NoSchedule]
[bootstrap-token] Using token: abcdef.0123456789abcdef
[bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstrap-token] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
[kubelet-finalize] Updating "/etc/kubernetes/kubelet.conf" to point to a rotatable kubelet client certificate and key
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:


# join master
#新master节点需要从主master节点copy以下证书
#在新master节点建立以下目录
mkdir -p /etc/kubernetes/pki/etcd/

#在master第一个主节点copy证书
mv pki/sa.* /etc/kubernetes/pki/
mv pki/ca.* /etc/kubernetes/pki/
mv pki/front-proxy-c* /etc/kubernetes/pki/
mv pki/etcd/ca.* /etc/kubernetes/pki/etcd/


$ kubectl edit cm kubeadm-config -n kube-system
# 添加
    controlPlaneEndpoint: 172.22.0.41:6443

kubeadm join 172.22.0.41:6443 --token abcdef.0123456789abcdef \
	--discovery-token-ca-cert-hash sha256:bf530d4363cafb20d5f88c0e52637af9a34f310fb2b58beaadc1fea05e15402d \
	--control-plane --certificate-key a858f1dfa07900d2c7e69307ca6ae5262436e0057445a4389b7e8ce805697079 \
	--ignore-preflight-errors=ImagePull
```

#### init 可能遇到的问题

```bash
error=\"open /run/containerd/io.containerd.runtime.v2.task/ init.pid: no such file or directory

## 解决方案: centos7默认的libseccomp的版本为2.3.1,不满足containerd的需求
rpm -qa |grep libseccomp
rpm -e --nodeps libseccomp-2.3.1-4.el7.x86_6
wget http://rpmfind.net/linux/centos/8-stream/BaseOS/x86_64/os/Packages/libseccomp-2.5.1-1.el8.x86_64.rpm
rpm -ivh libseccomp-2.5.1-1.el8.x86_64.rpm
#重启下服务器

Error registering network: failed to acquire lease: subnet "10.10.0.0/16" specified in the flannel net config doesn't contain "10.244.0.0/24" PodCIDR of the "kino1" node
vi kube-flannel.yml

 
 net-conf.json: |
    {
      "Network": "172.16.0.0/16",
      "Backend": {
        "Type": "vxlan"    ## vxlan 可以在内核态进行IP包的封装和解封装操作
      }
    }
    


## 问题: "Error getting node" err="node \"prod.ds.idas03.idc\" not found"
## 解决方案
## containerd 没有配置好, 看 harbor 中: make container able to pull, 给containerd增加证书         
```

#### 设置 .kube/config

```bash
# (只在master执行)
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

#### 网络插件

##### calico

````bash
# calico网络插件安装(网络插件可以二选一)
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
# 查看master状态
[root@master ~]# kubectl get pods -A
NAMESPACE     NAME                                       READY   STATUS     RESTARTS      AGE
kube-system   calico-kube-controllers-5b97f5d8cf-qrg87   0/1     Pending    0             2m36s
kube-system   calico-node-4j8s9                          0/1     Init:0/3   0             2m36s
kube-system   calico-node-7vnhb                          0/1     Init:0/3   0             2m36s
kube-system   coredns-74586cf9b6-glsgz                   0/1     Pending    0             14h
kube-system   coredns-74586cf9b6-hgtf7                   0/1     Pending    0             14h
kube-system   etcd-master                                1/1     Running    1 (54m ago)   14h
kube-system   kube-apiserver-master                      1/1     Running    1 (54m ago)   14h
kube-system   kube-controller-manager-master             1/1     Running    1 (54m ago)   14h
kube-system   kube-proxy-mq7b9                           1/1     Running    1 (53m ago)   14h
kube-system   kube-proxy-wwr6d                           1/1     Running    1 (54m ago)   14h
kube-system   kube-scheduler-master                      1/1     Running    1 (54m ago)   14h
````

##### flannel

```bash
# flannel 网络插件安装
# wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

cd k8s/network
kubectl apply -f flannel.yaml


# Error registering network: failed to acquire lease: subnet "10.10.0.0/16" specified in the flannel n
vi flannel.yaml
net-conf.json: |
    {
      "Network": "10.244.0.0/24",  ## 修改这里
      "Backend": {
        "Type": "vxlan"
      }
    }
kubectl delete pod flannel..... # 重启pod


# Error registering network: failed to acquire lease: node "prod.ds.idas06.idc" pod cidr not assigned
```

#### join k8s集群

```bash
[root@master ~]# kubectl get nodes
NAME     STATUS     ROLES           AGE   VERSION
master   NotReady   control-plane   14h   v1.24.4
# node1节点加入集群
$ kubeadm join 10.1.1.10:6443 --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:3effc72f50d0cefff23de6b4bece8962b59bc8e57b2ab641cb0bfd36460f1c4f 
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.

# 加入后在master节点查看状态
kubectl get nodes
```

#### 证书过期

```bash
# 9、node节点加入集群令牌有效期为24小时，master节点可以生成新令牌
[root@master ~]# kubeadm token create --print-join-command
kubeadm join 10.1.1.10:6443 --token 52nf1s.puunevi6fxb9xit6 --discovery-token-ca-cert-hash sha256:3effc72f50d0cefff23de6b4bece8962b59bc8e57b2ab641cb0bfd36460f1c4f 

# 使node节点也可以执行kubectl命令
scp -r $HOME/.kube node1:$HOME
kubectl get nodes
```

### master node 设置可调度

```bash
kubectl taint node kino1 node-role.kubernetes.io/master-
kubectl uncordon kino1
```

### 卸载k8s集群

```bash
yum remove -y kubelet kubeadm kubectl
kubeadm reset -f
modprobe -r ipip
lsmod
ipvsadm --clear
rm -rf ~/.kube/
rm -rf /etc/kubernetes/
rm -rf /etc/systemd/system/kubelet.service.d
rm -rf /etc/systemd/system/kubelet.service
rm -rf /usr/bin/kube*
rm -rf /etc/cni
rm -rf /opt/cni
rm -rf /var/lib/etcd
rm -rf /var/etcd
rm -rf $HOME/.kube
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
```

## ingress nginx install

```bash
# $ curl -o ingress-gninx.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.3.0/deploy/static/provider/baremetal/deploy.yaml 
# 
# $ vim ingress-gninx.yaml 

$ cd k8s/ingress-nginx
$ kubectl apply -f ingress-nginx.yaml
```

## volcano install

```bash
$ cd k8s/volcano
# 可能需要修改镜像

# 创建namespace
kubectl create ns daas
# 修改namespace
$ vim volcano-development.yaml
# 部署
$ kubectl apply -f volcano-development.yaml 
# 查看
$ kubectl get pod -n daas
```

## 证书续期

```bash
# 查看证书有效期
$ kubeadm certs check-expiration

# 安装go环境
wget https://studygolang.com/dl/golang/go1.17.1.linux-amd64.tar.gz
tar axf go1.17.1.linux-amd64.tar.gz -C /usr/local/
echo "export PATH=$PATH:/usr/local/go/bin" >> /etc/profile
source /etc/profile

# clone k8s 源码
mkdir -p /data/k8s-src && cd /data/k8s-src
wget https://github.com/kubernetes/kubernetes/archive/refs/tags/v1.21.9.zip
unzip v1.21.9.zip

# 修改Kubeadm源码包更新证书策略
cd kubernetes-1.21.9
vim cmd/kubeadm/app/util/pkiutil/pki_helpers.go

# 1、添加内容
const effectyear = time.Hour * 24 * 365 * 100
NotAfter:     time.Now().Add(effectyear).UTC(),
# 注意：vim staging/src/k8s.io/client-go/util/cert/cert.go #kubeadm1.14版本之前
# 2、注释内容（如下图所示）
// NotAfter:     time.Now().Add(kubeadmconstants.CertificateValidity).UTC(),

# 3、编译kubeadm
# 注意路径
cd kubernetes-1.21.9
yum install rsync -y
make WHAT=cmd/kubeadm

# 4、原证书备份
cd kubernetes-1.21.9
cp -arp /etc/kubernetes /etc/kubernetes_`date +%F`
mv /usr/bin/kubeadm /usr/bin/kubeadm_`date +%F`
cp -a _output/bin/kubeadm /usr/bin

# 5、证书更新
kubeadm certs renew all

# Done renewing certificates. You must restart the kube-apiserver, kube-controller-manager, kube-scheduler and etcd, so that they can use the new certificates.
# 重启 kube-apiserver, kube-controller-manager, kube-scheduler and etcd

# 6、查看证书有效期
kubeadm certs check-expiration

# 7、备份另外两个matser节点证书文件及kubeadm工具
cp -arp /etc/kubernetes /etc/kubernetes_`date +%F`
mv /usr/bin/kubeadm /usr/bin/kubeadm_`date +%F`
# 8、将第一个master更新好的kubeadm工具拷贝到另外两个master节点的/usr/bin目录下
scp /usr/bin/kubeadm root@192.168.1.213:/usr/bin
chmod +x /usr/bin/kubeadm
scp /usr/bin/kubeadm root@192.168.1.214:/usr/bin
chmod +x /usr/bin/kubeadm
# 9、证书更新
kubeadm certs renew all
# 10、查看证书有效期
kubeadm certs check-expiration
```

