
# 변수 정의
ariable "region" {
        description = "AWS region to deploy resources"
        type = string
        default = "ap-northeast-2"
}
variable "key_name" {
        description = "Name of the AWS key pair"
        type = string
}
variable "public_key_path" {
        description = "Path to the public key file for SSH access"
        type = string
}
