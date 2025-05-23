provider "aws"  {
	region = var.region
}

# 마스터 노드 작성
locals {
	master_script = <<-EOM
#!/bin/bash

set -eux
cat <<'EOSH' > /root/master.sh
#!/bin/bash
set -eux
# Swap 비활성화
swapoff -a
sed -i '/ swap /s/^/#/' /etc/fstab
# host 이름 변경
hostnamectl set-hostname k8scp
exec bash

# containerd 설치 
yum install -y containerd
# containerd 기본 설정 적용
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# containerd 서비스 활성화
systemctl enable --now containerd

# 모듈 로드
cat<<MODS > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
MODS
modprobe overlay
modprobe br_netfilter

# sysctl 설정
cat <<SYSCTL > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
SYSCTL
sysctl --system

# Kubernetes 저장소 설정
cat <<REPO > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
REPO

# Kubernetes 설치
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable --now kubelet

# Kubernetes 초기화
kubeadm init --ignore-preflight-errors=NumCPU --ignore-preflight-errors=Mem > /root/init.log

# kubeconfig 파일 설정
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

# API 서버 응답 대기
export KUBECONFIG=/etc/kubernetes/admin.conf
until KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes > /dev/null 2>&1; 
do
	echo "Waiting for API server to respond..."
 	sleep 5
done

# Weave CNI 설치
echo "Installing CNI(Weave) ..."
for i in {1..5}; do
	 if KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml; then
		echo "Weave CNI install Success"
		break
	else
		echo "Weave Install Failed, retry in 5 seconds..."
		sleep 5
	fi
done
echo "Master setup complete"
EOSH

chmod +x /root/master.sh
/root/master.sh
EOM
# 워커 노드 작성 시작
	worker_script = <<-EOW
#!/bin/bash
set -eux
cat <<'EOSH' > /root/worker.sh
#!/bin/bash
set -eux

# Swap 비활성화
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# host 이름 변경
hostnamectl set-hostname k8swn
exec bash

# containerd 설치
yum install -y containerd

# containerd 기본 설정 적용
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# containerd 서비스 활성화
systemctl enable --now containerd

# 모듈 로드
cat <<MODS > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
MODS
modprobe overlay
modprobe br_netfilter

# sysctl 설정
cat <<SYSCTL > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
SYSCTL
sysctl --system

# Kubernetes 저장소 설정
cat <<REPO > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
REPO

# kubelet kubeamd kubectl 설치
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# 서비스 활성화
systemctl enable --now kubelet
echo "Worker node setup complete. Waiting for join."
EOSH

chmod +x /root/worker.sh
/root/worker.sh
EOW
}

locals{
	jenkins_script = <<-EOJ
#!/bin/bash
set -eux
cat <<'EOSH' > /root/install.sh

#!/bin/bash
set -eux
# Swap 비활성화
swapoff -a
sed -i '/ swap /s/^/#/' /etc/fstab

# host 이름 변경
hostnamectl set-hostname jenkins
exec bash

# git 설치
dnf install -y git 

# jenkins 설치
wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
yum install -y fontconfig java-21-amazon-corretto
yum install -y jenkins

#젠킨스 서비스 활성화
systemctl daemon-reload
systemctl enable --now jenkins


# Maven 설치
wget https://dlcdn.apache.org/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.zip 
tar -xvzf apache-maven-3.9.9-bin.tar.gz
mv apache-maven-3.9.9 /opt/maven

# maven 환경 설정 추가


echo "Jenkins setup complete"
# 초기비밀번호
cat /var/lib/jenkins/secrets/initialAdminPassword >> /root/initpassword
chmod 600 /root/initpassword

EOSH

chmod +x /root/install.sh
/root/install.sh
EOJ
}

locals {
	ansdoc_script = <<-EOAD
#!/bin/bash
set -eux

cat <<'EOSH' > /root/install.sh
#!/bin/bash
set -eux

# Swap 비활성화
swapoff -a
sed -i '/ swap /s/^/#/' /etc/fstab

# host 이름 변경
hostnamectl set-hostname ansdoc
exec bash

# ansible + docker 설치
dnf -y install ansible docker

# docker 활성화
systemctl enable --now docker

# 사용자 추가 및 비밀번호 설정
useradd ansdocadmin
echo "ansdocadmin:devops" | chpasswd

# sudo 권한 부여
echo 'ansdocadmin ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansdocadmin
chmod 440 /etc/sudoers.d/ansdocadmin

# docker 그룹 추가
usermod -aG docker ansdocadmin

# CI/CD 파이프라인 작업 디렉토리 생성
mkdir /opt/ansdoc
chown -R ansdocadmin:ansdocadmin /opt/ansdoc

EOSH

chmod +x /root/install.sh
bash /root/install.sh
EOAD
}

# AWS 리소스 생성
# VPC 생성
resource "aws_vpc" "devops_vpc" {
	cidr_block = "10.0.0.0/16"
	enable_dns_support = true
	enable_dns_hostnames = true
	tags ={
		Name = "devops_vpc"
	}
}
# public subnet - 1 생성
resource "aws_subnet" "public_subnet_1"{
	vpc_id = aws_vpc.devops_vpc.id
	cidr_block = "10.0.1.0/24"
	availability_zone = "ap-northeast-2a"
	map_public_ip_on_launch = true
	tags = {
		Name = "devops-public-subnet-1"
	}
}
# public subnet - 2 생성
resource "aws_subnet" "public_subnet_2"{
	vpc_id = aws_vpc.devops_vpc.id
	cidr_block = "10.0.3.0/24"
	availability_zone = "ap-northeast-2c"
	map_public_ip_on_launch = true
	tags = {
		Name = "devops_vpc-public-subnet-2"
	}
}
# private subnet - 1 생성
resource "aws_subnet" "private_subnet_1"{
	vpc_id = aws_vpc.devops_vpc.id
	cidr_block = "10.0.2.0/24"
	availability_zone = "ap-northeast-2a"
	map_public_ip_on_launch = false
	tags = {
		Name = "devops_vpc-private-subnet-1"
	}
}
# private subnet -2 생성
resource "aws_subnet" "private_subnet_2"{
	vpc_id = aws_vpc.devops_vpc.id
	cidr_block = "10.0.4.0/24"
	availability_zone = "ap-northeast-2c"
	map_public_ip_on_launch = false
	tags ={
		Name = "devops_vpc-private-subnet-2"
	}
}

# internet gateway 생성
resource "aws_internet_gateway" "devops_igw"{
	vpc_id = aws_vpc.devops_vpc.id
}

# public routing table 생성
resource "aws_route_table" "public_rt"{
	vpc_id = aws_vpc.devops_vpc.id
	# igw 라우팅 테이블 경로 추가가
	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = aws_internet_gateway.devops_igw.id
	}
	tags = {
		Name = "devops-public-rt"
	}
}
# public subnet_1에 라우팅 테이블 연결
resource "aws_route_table_association" "public_rta_1" {
	subnet_id = aws_subnet.public_subnet_1.id
	route_table_id = aws_route_table.public_rt.id
}
# public subnet_2에 라우팅 테이블 연결
resource "aws_route_table_association" "public_rta_2" {
	subnet_id = aws_subnet.public_subnet_2.id
	route_table_id = aws_route_table.public_rt.id
}
# 탄력적 public ip 할당 -1
resource "aws_eip" "nat_eip_1"{
	domain = "vpc"
}
# 탄력적 public ip 할당 -2
resource "aws_eip" "nat_eip_2"{
	domain = "vpc"
}
# NAT gateway_1 생성
resource "aws_nat_gateway" "nat_gw_1"{
	subnet_id = aws_subnet.public_subnet_1.id
	allocation_id = aws_eip.nat_eip_1.id
	depends_on = [aws_internet_gateway.devops_igw]
	tags = {
		Name = "devops-ngw-1"
	}
}
# NAT gateway_2 생성
resource "aws_nat_gateway" "nat_gw_2"{
	subnet_id = aws_subnet.public_subnet_2.id
	allocation_id = aws_eip.nat_eip_2.id
	depends_on = [aws_internet_gateway.devops_igw]
		tags = {
		Name = "devops-ngw-2"
	}
}
# private subnet -1 routing table  생성 및 ngw-1 경로 추가
resource "aws_route_table" "private_rt_1" {
	vpc_id = aws_vpc.devops_vpc.id
	route {
		cidr_block = "0.0.0.0/0"
		nat_gateway_id = aws_nat_gateway.nat_gw_1.id
	}
	tags = {
		Name = "devops-private-rt-1"	
	}
}
# private subnet_1 경로 추가
resource "aws_route_table_association" "private_rta_1" {
	subnet_id      = aws_subnet.private_subnet_1.id
	route_table_id = aws_route_table.private_rt_1.id
}
# private subnet -2 routing table 생성 및 ngw-2 경로 추가
resource "aws_route_table" "private_rt_2" {
	vpc_id = aws_vpc.devops_vpc.id
	route {
		cidr_block = "0.0.0.0/0"
		nat_gateway_id = aws_nat_gateway.nat_gw_2.id
	}
	tags = {
		Name = "devops-private-rt-2"	
	}
}

# private subnet_2 경로로 추가
resource "aws_route_table_association" "private_rta_2" {
	subnet_id = aws_subnet.private_subnet_2.id
	route_table_id = aws_route_table.private_rt_2.id
}
# k8s control plane 보안 그룹 생성
resource "aws_security_group" "k8s_master_sg" {
	name 		= "k8s-master-sg"
	description = "SG for k8s mater node"
	vpc_id 		= aws_vpc.devops_vpc.id
 	ingress {
	    from_port   = 6443
	    to_port     = 6443
	    protocol    = "tcp"
	    cidr_blocks = ["0.0.0.0/0"]
  	}
  	ingress {
	    from_port   = 2379
	    to_port     = 2380
	    protocol    = "tcp"
	    cidr_blocks = ["10.0.0.0/16"]
	}
  	ingress {
	    from_port   = 10250
	    to_port     = 10259
	    protocol    = "tcp"
	    cidr_blocks = ["10.0.0.0/16"]
  	}
  	ingress {
	    from_port   = 6783
	    to_port     = 6783
	    protocol    = "tcp"
	    cidr_blocks = ["10.0.0.0/16"]
  	}
  	ingress {
	    from_port   = 6783
	    to_port     = 6784
	    protocol    = "udp"
	    cidr_blocks = ["10.0.0.0/16"]
  	}
  	egress {
	    from_port   = 0
	    to_port     = 0
	    protocol    = "-1"
	    cidr_blocks = ["0.0.0.0/0"]
  	}
 	tags = {
    	Name = "k8s-master-sg"
  	}	
}
# k8s worknode 보안 그룹 생성
resource "aws_security_group" "k8s_worker_sg"{
	name 		= "k8s-worker-sg"
	description = "SG for k8s worker nodes"
	vpc_id 		= aws_vpc.devops_vpc.id
	ingress {
		from_port = 10250
		to_port = 10250
		protocol = "tcp"
		cidr_blocks = ["10.0.0.0/16"]
	}
	ingress {
		from_port = 30000
		to_port = 32767
		protocol = "tcp"
		cidr_blocks = ["10.0.0.0/16"]
	}
	ingress {
		from_port = 6783
		to_port = 6783
		protocol = "tcp"
		cidr_blocks = ["10.0.0.0/16"]
	}
	ingress {
		from_port = 6783
		to_port = 6784
		protocol = "udp"
		cidr_blocks = ["10.0.0.0/16"]
	}
  	egress {
	    from_port   = 0
	    to_port     = 0
	    protocol    = "-1"
	    cidr_blocks = ["0.0.0.0/0"]
  	}
	tags = {
    	Name = "k8s-worker-sg"
  	}	
}
# bastion server 보안 그룹 생성
resource "aws_security_group" "bastion_sg"{
	name 		= "bastion-sg"
	description = "Bastion SSH Access"
	vpc_id 		= aws_vpc.devops_vpc.id

	ingress {
		from_port = 22
		to_port = 22
		protocol ="tcp"
		cidr_blocks =  ["0.0.0.0/0"]
	}
	egress {
	    from_port   = 0
	    to_port     = 0
	    protocol    = "-1"
	    cidr_blocks = ["0.0.0.0/0"]
  	}
	tags = {
		Name = "bastion-sg"
	}
}
# jenkins 보안 그룹 생성
resource "aws_security_group" "jenkins_sg"{
	name 		= "jenkins-sg"
	description = "SG for Jenkins CI server"
	vpc_id 		= aws_vpc.devops_vpc.id
	ingress {
		from_port   = 8080
		to_port     = 8080
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
	tags = {
    	Name = "jenkins-sg"
  	}
}
# RDS 보안 그룹 생성
resource "aws_security_group" "rds_sg" {
	name        = "rds-sg"
	description = "RDS MySQL Access"
	vpc_id      = aws_vpc.devops_vpc.id

	ingress {
		from_port   = 3306
		to_port     = 3306
		protocol    = "tcp"
		security_groups = [
		aws_security_group.k8s_worker_sg.id,
		aws_security_group.jenkins_sg.id
		]
	}

	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

	tags = {
		Name = "rds-sg"
	}
}
# Ansible + Docker 보안 그룹 생성
resource "aws_security_group" "ansdoc_sg" {
	name        = "ansible-docker-sg"
	description = "SG for Ansible + Docker Server"
	vpc_id      = aws_vpc.devops_vpc.id

	ingress {
		from_port   = 22
		to_port     = 22
		protocol    = "tcp"
		security_groups = [aws_security_group.bastion_sg.id] # 점프서버에서만 접속 허용
	}

	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

	tags = {
		Name = "ansible-docker-sg"
	}
}

# load balancer 보안 그룹 생성
resource "aws_security_group" "load_balancer_sg" {
	name 		= "loadBalanacer-sg"
	description = "SG for load_blancer"
	vpc_id 		= aws_vpc.devops_vpc.id

	ingress {
		from_port   = 80
		to_port     = 80
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	ingress {
		from_port   = 443
		to_port     = 443
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
		egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

	tags = {
		Name = "loadBalanacer-sg"
	}
}

# 젠킨스 로드밸런서 보안 그룹 생성
resource "aws_security_group" "jenkins_lb_sg" {
	name 		= "lb-jenkins-sg"
	description = "SG for load_blancer"
	vpc_id 		= aws_vpc.devops_vpc.id

	ingress {
		from_port   = 80
		to_port     = 80
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	ingress {
		from_port   = 443
		to_port     = 443
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
		egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

	tags = {
		Name = "lb-jenkins-sg"
	}
}
# key pair 생성
resource "aws_key_pair" "k8s_key" {
key_name   = var.key_name
public_key = file(var.public_key_path)
}	

# 쿠버네티스 노드 생성 control-plane 1개 worknode 2개
resource "aws_instance" "k8s_nodes" {
	count = 3
	ami = "ami-0f605570d05d73472"
	instance_type = "t2.micro"
	key_name = var.key_name

	vpc_security_group_ids = [
		aws_vpc.devops_vpc.default_security_group_id,
		count.index == 0 ? aws_security_group.k8s_master_sg.id : aws_security_group.k8s_worker_sg.id
	]
	user_data = (
      count.index == 0 ? local.master_script : local.worker_script
  	)
  	subnet_id = (
    	count.index == 0 ? aws_subnet.private_subnet_1.id : aws_subnet.private_subnet_2.id
  	)
  	tags = {
	    Name = count.index == 0 ? "k8s-master" : "k8s-worker-${count.index}"
	    Role = count.index == 0 ? "master" : "worker"
  	}
}
# jenkins 인스턴스 생성
resource "aws_instance" "jenkins"{
	count = 1
	ami = "ami-0f605570d05d73472"
	instance_type = "t3.small"
	key_name = var.key_name

	vpc_security_group_ids = [
		aws_vpc.devops_vpc.default_security_group_id,
		aws_security_group.jenkins_sg.id
	]
	subnet_id = aws_subnet.private_subnet_1.id
	user_data = local.jenkins_script
	tags = {
		Name = "devops-jenkins"
	}
}
# Ansible + Docker 인스턴스 생성
resource "aws_instance" "ansdoc"{
	count = 1
	ami = "ami-0f605570d05d73472"
	instance_type = "t2.micro"
	key_name = var.key_name

	vpc_security_group_ids = [
		aws_vpc.devops_vpc.default_security_group_id,
		aws_security_group.ansdoc_sg.id
	]
	subnet_id = aws_subnet.private_subnet_1.id
	user_data = local.ansdoc_script
	tags = {
		Name = "devops-ansdoc"
	}
}
# 점프 서버 인스턴스 생성
resource "aws_instance" "n"{
	count = 1
	ami = "ami-0f605570d05d73472"
	instance_type = "t2.micro"
	key_name = var.key_name

	vpc_security_group_ids = [
		aws_vpc.devops_vpc.default_security_group_id,
		aws_security_group.bastion_sg.id
	]
	subnet_id = aws_subnet.public_subnet_1.id
	tags = {
		Name = "devops-bastion_server"
	}
}

# web service 타겟 그룹 생성
resource "aws_lb_target_group" "Web_tg"{
	name = "devops-web-tg"
	port = 30080
	protocol = "HTTP"
	vpc_id = aws_vpc.devops_vpc.id

	health_check {
		interval            = 15
		path                = "/index.html"
		port                = "traffic-port"  # ← 보통 'traffic-port'로 두면 타겟그룹 port(30080)를 그대로 사용
		protocol            = "HTTP"
		timeout             = 5
		unhealthy_threshold = 2
		matcher             = "200-299"
	}
}
# web service 타겟그룹 대상 등록
resource "aws_lb_target_group_attachment" "web_tg_attachment"{
	for_each = {
		for idx, inst in aws_instance.k8s_nodes :
		idx => inst
		if idx != 0  # index 0은 master, 제외
	}

	target_group_arn = aws_lb_target_group.Web_tg.arn
	target_id        = each.value.id
	port             = 30080                 # ← 여기에도 NodePort (30080) 지정

}

# web service 로드 밸런서 연결
resource "aws_lb" "application_load_bastion" {
	name 		= "webService-lb"
	internal	= false
	load_balancer_type = "application"
	security_groups = [aws_security_group.load_balancer_sg.id]
	subnets = [  aws_subnet.public_subnet_1.id,
				aws_subnet.public_subnet_2.id
			]

	enable_deletion_protection = false

	tags = {
		Environment = "production"
	}
}
# web_lb_listener 구성
resource "aws_lb_listener" "web_listener" {
	load_balancer_arn = aws_lb.application_load_bastion.arn
	port              = 80
	protocol          = "HTTP"

	default_action {
		type             = "forward"
		target_group_arn = aws_lb_target_group.Web_tg.arn
	}
}

# Jenkins 타겟 그룹 생성
resource "aws_lb_target_group" "jenkins_tg" {
  name     = "devops-jenkins-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.devops_vpc.id

  health_check {
    interval            = 15
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

# Jenkins 타겟 그룹 대상 등록
resource "aws_lb_target_group_attachment" "jenkins_tg_attachment" {
	target_group_arn = aws_lb_target_group.jenkins_tg.arn
	target_id        = aws_instance.jenkins[0].id
	port             = 8080
}

# Jenkins용 로드 밸런서 생성
resource "aws_lb" "application_load_jenkins" {
	name               = "jenkins-lb"
	internal           = false
	load_balancer_type = "application"
	security_groups    = [aws_security_group.jenkins_lb_sg.id]
	subnets            = [
			aws_subnet.public_subnet_1.id,
			aws_subnet.public_subnet_2.id
	]

  	enable_deletion_protection = false

	tags = {
	Environment = "production"
	}
}

# Jenkins용 리스너 구성
resource "aws_lb_listener" "jenkins_listener" {
	load_balancer_arn = aws_lb.application_load_jenkins.arn
	port              = 80
	protocol          = "HTTP"

	default_action {
		type             = "forward"
		target_group_arn = aws_lb_target_group.jenkins_tg.arn
	}
}


# RDS 서비스 생성
resource "aws_db_instance" "

# AWS S3 Bucket 와 Ec2 instance 연결

# Route 53 도메인 연결
