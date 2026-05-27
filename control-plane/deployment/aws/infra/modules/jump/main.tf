/**
 * # jump
 *
 * Creates an EC2 instance for SSM-based access to private VPC resources. No SSH keys
 * or inbound security group rules are required — the instance connects outbound to the
 * SSM service via the NAT gateway. Used to establish port-forwarding tunnels to the
 * RDS instance and the private EKS API server endpoint.
 */

resource "aws_iam_role" "jump" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "jump_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.jump.name
}

resource "aws_iam_instance_profile" "jump" {
  name = var.role_name
  role = aws_iam_role.jump.name
}

resource "aws_security_group" "jump" {
  name        = var.sg_name
  description = "SSM jump instance - no inbound rules, outbound HTTPS only"
  vpc_id      = var.vpc_id
  tags        = { Name = var.sg_name }
}

# SSM agent connects outbound to SSM endpoints via the NAT gateway — no inbound rules required.
resource "aws_vpc_security_group_egress_rule" "jump_egress_ssm" {
  description       = "Allow SSM agent to reach SSM endpoints"
  security_group_id = aws_security_group.jump.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_instance" "jump" {
  ami                    = var.ami_id != null ? var.ami_id : data.aws_ami.amazon_linux_2023[0].id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.jump.name
  vpc_security_group_ids = [aws_security_group.jump.id]

  # Require IMDSv2 to prevent SSRF against the instance metadata service.
  metadata_options {
    http_tokens = "required"
  }

  tags = { Name = var.instance_name }
}
