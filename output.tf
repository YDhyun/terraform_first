output "bastion_server_pubilc_ip"{
    value = aws_instance.bastion_server[0].public_ip
}

output "jenkins_private_ip" {
  value = aws_instance.jenkins[0].private_ip
}

output "ansdoc_private_ip" {
  value = aws_instance.ansdoc[0].private_ip
}

output "master_private_ip" {
    value = aws_instance.k8s_nodes[0].private_ip
}
output "worker_private_ips" {
    value = [for i in aws_instance.k8s_nodes : i.private_ip if i.tags["Role"] == "worker"]
}

