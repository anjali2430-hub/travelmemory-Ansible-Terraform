# Latest Ubuntu 22.04 LTS AMI from Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------- SSH key pair
# Terraform generates the key; the private half is written next to the Ansible code (git-ignored).
resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ssh.private_key_openssh
  filename        = "${path.module}/../ansible/keys/${var.project_name}-key.pem"
  file_permission = "0400"
}

# ---------------------------------------------------------------- Web server (public subnet)
resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.deployer.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  metadata_options {
    http_tokens   = "required" # IMDSv2 only
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  tags = { Name = "${var.project_name}-web", Role = "web" }
}

# Static public IP so the URL survives stop/start
resource "aws_eip" "web" {
  domain   = "vpc"
  instance = aws_instance.web.id
  tags     = { Name = "${var.project_name}-web-eip" }

  depends_on = [aws_internet_gateway.igw]
}

# ---------------------------------------------------------------- Database server (private subnet)
resource "aws_instance" "db" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.db_instance_type
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.db.id]
  key_name                    = aws_key_pair.deployer.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = false

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  # Needs the NAT gateway for apt on first boot
  depends_on = [aws_nat_gateway.nat, aws_route_table_association.private]

  tags = { Name = "${var.project_name}-db", Role = "db" }
}

# ---------------------------------------------------------------- Ansible inventory
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory/hosts.ini"
  file_permission = "0644"
  content = templatefile("${path.module}/templates/hosts.ini.tftpl", {
    web_public_ip  = aws_eip.web.public_ip
    web_private_ip = aws_instance.web.private_ip
    db_private_ip  = aws_instance.db.private_ip
    key_file       = "keys/${var.project_name}-key.pem"
    admin_cidr     = local.admin_cidr
    vpc_cidr       = var.vpc_cidr
  })
}
