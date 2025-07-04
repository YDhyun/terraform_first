# terraform_first
## 자동화·가상화(DevOps) 기반 정보보안 클라우드 인프라 전문과정 최종 프로젝트
### 목표
Terraform을 활용하여 AWS 리소스를 자동으로 생성하고, 이를 기반으로 CI/CD 인프라 환경을 구축하는 것을 목표로 한다.


---

구성하고자 하는 AWS 인프라 아키텍처
![AWS 인프라 아키텍처](./images/architecture.png)

## 현재 완성된 리소스 작업
### VPC 네트워크 구성
- VPC 생성
- 퍼블릭/프라이빗 Subnet 생성 (AZ 분산)
- Internet Gateway 연결
- NAT Gateway 구성 (AZ별 1개)
- 탄력적 IP(EIP) 할당
- Routing Table 설정 및 Subnet 연결

### 보안 그룹 설정 (Security Group)
- `bastion_sg` : Bastion 서버 접근 제어
- `jenkins_sg` : Jenkins 서버 접근 허용
- `ansdoc_sg` : Ansible + Docker 서버 전용 SG
- `k8s_master_sg` : 쿠버네티스 Control Plane 전용 SG
- `k8s_worker_sg` : 쿠버네티스 워커 노드 전용 SG
- `was_lb_sg` : Web 서비스용 ALB SG
- `jenkins_lb_sg` : Jenkins 전용 ALB SG

### EC2 인스턴스 구성
- `bastion` : SSH 점프서버
- `jenkins` : CI 서버
- `ansdoc` : Ansible + Docker 서버
- `k8s_nodes` : Control Plane 1개 + Worker Node 2개

### 로드 밸런서 구성 (ALB)
- `jenkins_lb` : Jenkins 접근용 Application Load Balancer
- `was_lb` : Web 서비스용 Load Balancer (30080 포트 사용)

### 로드 밸런서 생성
  - jenkins_lb
  - was_lb

---
## 🔧 앞으로 추가할 리소스

- IAM 사용자 및 정책 구성
- RDS (MySQL 이용)
- S3 버킷 생성 및 웹 자산 저장
- Route 53을 통한 도메인 연결

## 📌 기타 정보

- 키 페어는 보안을 위해 로컬에서 수동 생성하여 Terraform이 참조하도록 구성
- Terraform 구성은 이후 `모듈화 프로젝트`로 확장하여 별도 리팩토링 예정


## 사용 방법
1. 테라폼을 OS에 맞춰서 설치 : https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli#install-terraform
2. aws cli 설치 
3. aws configure (aws access 키 만들기)
4. 테라폼 동작 
- a. 초기화 : terraform init
- b. 유효성(문법) 검사 : terraform validate
- c. 계획 확인 : terraform plan
- d. 적용 : terraform apply
- e. 제거 : terraform destroy