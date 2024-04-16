# https://mirrors.aliyun.com/centos/7.9.2009/isos/x86_64/CentOS-7-x86_64-Minimal-2207-02.iso
# centos7 init
echo "export LC_ALL=en_US.UTF-8" >> /etc/profile
echo "export LC_CTYPE=en_US.UTF-8" >> /etc/profile
source /etc/profile

# vim /etc/default/grub
# grub2-mkconfig -o /boot/grub2/grub.cfg
# vi /etc/sysconfig/network-scripts/ifcfg-ens32

mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo

# soft prepare
yum upgrade -y && yum update -y
yum install -y device-mapper-persistent-data git glibc-langpack-en ipset ipset ipvsadm ipvsadm libaio lvm2 net-tools ntp ntp-doc ntpdate openssh openssh-clients rsync tar telnet unzip vim wget yum-utils zip

timedatectl list-timezones
ntpdate time.windows.com
timedatectl status
date

# install docker
yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum -y install docker-ce docker-ce-cli containerd.io
systemctl enable docker
systemctl start docker

# k8s yum repo
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

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
cat << EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system
modprobe br_netfilter
modprobe overlay
lsmod | grep -e br_netfilter -e overlay
# ipvs设置
yum install ipset ipvsadm -y
cat > /etc/sysconfig/modules/ipvs.modules << EOF
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

cat > /etc/hosts << EOF
192.168.2.210 k8s00
192.168.2.211 k8s01
192.168.2.212 k8s02
192.168.2.213 k8s03
EOF

yum install -y kubelet-1.21.9 kubeadm-1.21.9 kubectl-1.21.9
systemctl enable kubelet

kubeadm init \
  --ignore-preflight-errors=ImagePull \
  --apiserver-advertise-address=192.168.2.211 \
  --image-repository=registry.aliyuncs.com/google_containers \
  --kubernetes-version v1.21.9 \
  --service-cidr=10.96.0.0/12 \
  --pod-network-cidr=10.244.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=/etc/kubernetes/admin.conf

kubeadm token create --print-join-command

kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get pod,svc


#curl -O "http://melina/k8s.zip" && unzip k8s.zip
#sh install.sh
#kubeadm init --config=kubeadm.yml --upload-certs --ignore-preflight-errors=ImagePull
#
#kubectl taint nodes --all disk-pressure
#kubectl taint nodes --all disk-pressure:NoSchedule
#kubectl taint nodes --all node-role.kubernetes.io/control-plane-
#kubectl taint nodes --all node.kubernetes.io/disk-pressure:NoSchedule
#kubectl taint nodes --all node-role.kubernetes.io/master-