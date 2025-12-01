
provider "aws" {
  region     = "us-east-1"
}

resource "aws_instance" "flask_app" {
  ami           = "ami-0c55b159cbfafe1f0" # Amazon Linux 2
  instance_type = "t2.micro"

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install docker -y
              service docker start
              docker run -d -p 5000:5000 ${var.docker_image}
              EOF

  tags = {
    Name = "FlaskAppServer"
  }
}
