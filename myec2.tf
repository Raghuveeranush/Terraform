variable "instance_type" {
  type = map
  default = {
    default = "t2.micro"
    dev = "t2.micro"
    prod = "t2.large"
  }
  
}

resource "aws_instance" "demo-server" {
  ami = "ami-06791f9213cbb608b"
  instance_type = lookup(var.instance_type,terraform.workspace,"Invalid_workspace")
  associate_public_ip_address = true
  
}

output "eip_addr" {
  value = aws_instance.demo-server.public_ip
  
}
