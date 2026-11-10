# Offline test (no AWS account needed): `terraform test` / `tofu test`
# Mocks the providers and checks the network and security wiring of the plan.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["ap-south-1a", "ap-south-1b"] }
  }
  mock_data "aws_ami" {
    defaults = { id = "ami-0123456789abcdef0" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}
mock_provider "tls" {}
mock_provider "local" {}
mock_provider "http" {}

variables {
  admin_cidr = "203.0.113.10/32"
}

run "network_layout" {
  command = plan

  assert {
    condition     = aws_subnet.public.map_public_ip_on_launch == true && aws_subnet.private.map_public_ip_on_launch == false
    error_message = "Only the public subnet may assign public IPs"
  }
  assert {
    condition     = one(aws_route_table.private.route).cidr_block == "0.0.0.0/0"
    error_message = "Private subnet needs a default route (to the NAT gateway)"
  }
  assert {
    condition     = aws_instance.db.associate_public_ip_address == false
    error_message = "DB server must not have a public IP"
  }
}

run "security_rules" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_ingress_rule.web_ssh.cidr_ipv4 == "203.0.113.10/32"
    error_message = "SSH to the web server must be limited to the admin IP"
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.db_mongo.cidr_ipv4 == null && aws_vpc_security_group_ingress_rule.db_mongo.from_port == 27017
    error_message = "MongoDB must only be reachable from the web SG, never from a CIDR"
  }
  assert {
    condition     = aws_instance.web.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be enforced"
  }
  assert {
    condition     = aws_instance.web.root_block_device[0].encrypted && aws_instance.db.root_block_device[0].encrypted
    error_message = "Root volumes must be encrypted"
  }
}
