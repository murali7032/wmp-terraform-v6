resource "aws_security_group" "main" {

  name = "${var.component}-${var.env}"

  dynamic "ingress" {
    for_each = var.ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
      description = ingress.key
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.component}-${var.env}"
  }

}

resource "aws_instance" "main" {

  ami                    = data.aws_ami.ami.image_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.main.id]

  tags = {
    Name = "${var.component}-${var.env}"
  }
}

resource "aws_route53_record" "dns" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.component}-${var.env}"
  type    = "A"
  ttl     = 30
  records = [aws_instance.main.public_ip]
}

resource "null_resource" "ansible" {

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      host     = aws_instance.main.public_ip
      user     = "ec2-user"
      private_key = file(pathexpand(var.private_key_path))
 
    }
    inline = [
      "sudo labauto ansible",
      "ansible-pull -i localhost, -U https://github.com/raghudevopsb88/wmp-ansible-v4.git main.yml -e env=${var.env} -e COMPONENT=${var.component}"
    ]
  }
}



