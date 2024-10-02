resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev-vpc"
  }
}

resource "aws_subnet" "main_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.123.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-north-1a"

  tags = {
    Name = "dev-subnet"
  }
}

resource "aws_internet_gateway" "main_gw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_route_table" "main-rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "dev-rt"
  }
}

resource "aws_route" "main-r" {
  route_table_id         = aws_route_table.main-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_gw.id
}

resource "aws_route_table_association" "main-rta" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main-rt.id
}

resource "aws_security_group" "allow_tls_sg" {
  name        = "dev-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all inbound traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
}

resource "aws_key_pair" "ed_key" {
  key_name   = "edkey"
  public_key = file("~/.ssh/edkey.pub")
}

resource "aws_instance" "dev_node" {
  ami                    = data.aws_ami.server_ami.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.ed_key.id
  vpc_security_group_ids = [aws_security_group.allow_tls_sg.id]
  subnet_id              = aws_subnet.main_subnet.id
  user_data              = file("userdata.tpl")

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "dev-node"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-config.tpl", {
      hostname     = self.public_ip,
      user         = "ubuntu",
      identityfile = "~/.ssh/edkey"
    })
    interpreter = var.host_os == "windows" ? ["powershell", "-Command"] : ["bash", "-c"]
  }


}