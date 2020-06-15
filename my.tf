provider "aws"{
    region = "ap-south-1"
    profile = "myprakash"
}


resource "aws_security_group" "allow_tcp" {
  name        = "allow_tcp"
  description = "Allow tcp inbound traffic"
  vpc_id      = "vpc-2b495543"

  ingress {
    description = "SSH port"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    description = "HTTP port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

//Create new EC2 key pair

resource "tls_private_key" "mykey1" {
  algorithm = "RSA"
}
resource "aws_key_pair" "generated_key"{
   key_name   = "mykey1"
   public_key = "${tls_private_key.mykey1.public_key_openssh}"
  
  depends_on = [
    tls_private_key.mykey1
  ]
}


//Saving Private Key PEM File
resource "local_file" "key-file" {
  content  = "${tls_private_key.mykey1.private_key_pem}"
  filename = "mykey1.pem"
  
depends_on = [
    tls_private_key.mykey1
  ]
}


//Import existing public key as EC2 key pair

//module "key_pair" {
//  source = "terraform-aws-modules/key-pair/aws"

  //key_name   = "mykey1"
  //public_key = ""

//}


resource "aws_instance" "pkos" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = aws_key_pair.generated_key.key_name
  security_groups = [aws_security_group.allow_tcp.name ]


 provisioner "remote-exec" {
    
connection {
    agent = "false"
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.mykey1.private_key_pem}"
   host     = "${aws_instance.pkos.public_ip}"
  }

    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
      
    ]
  }

  tags = {
    Name = "pkos"
  }

}


resource "aws_ebs_volume" "esb1" {
  availability_zone = aws_instance.pkos.availability_zone
  size              = 1

  tags = {
    Name = "pkebsvol"
  }
}


resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.esb1.id
  instance_id = aws_instance.pkos.id
  force_detach = true
}

output "myip"{
  value = aws_instance.pkos.public_ip
}

resource "null_resource" "nullip"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.pkos.public_ip} > publicip.txt"
  	}
}
resource "null_resource" "nullremote1"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]

connection {
    agent = "false"
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.mykey1.private_key_pem}"
   host     = "${aws_instance.pkos.public_ip}"
  }
provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/prakashchoudhary110/multicloud.git /var/www/html/"
    ]
  }
}



//create bucket
//resource "aws_s3_bucket" "new_bucket" {
//bucket = "my-tf-test-bucket"
  //acl    = "public-read"

//  versioning {
    //enabled = true
   //}
//tags = {
   // Name = "my-new-buck"
   //Environment = "Dev"
  //}
//}

//Creating a S3 Bucket for Terraform Integration
resource "aws_s3_bucket" "pk-bucket" {
  bucket = "pk-static-data-bucket"
  acl    = "public-read"
}

//Putting Objects in S3 Bucket
resource "aws_s3_bucket_object" "web-object1" {
  bucket = "${aws_s3_bucket.pk-bucket.bucket}"
  key    = "pk.jpg"
  source = "C:/Users/sai/Desktop/pk.jpg"
  acl    = "public-read"
}

//Creating CloutFront with S3 Bucket Origin
resource "aws_cloudfront_distribution" "s3-web-distribution" {
  origin {
    domain_name = "${aws_s3_bucket.pk-bucket.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.pk-bucket.id}"
  }


  enabled             = true
  is_ipv6_enabled     = true
  comment             = "S3 Web Distribution"


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.pk-bucket.id}"


    forwarded_values {
      query_string = false


      cookies {
        forward = "none"
      }
    }


    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }


  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"] 
    }
  }


  tags = {
    Name        = "Web-CF-Distribution"
    Environment = "Production"
  }


  viewer_certificate {
    cloudfront_default_certificate = true
  }


  depends_on = [
    aws_s3_bucket.pk-bucket
  ]
}


//resource "null_resource" "remote1" {
  
  //depends_on = [ aws_instance.pkos ]
  
//Executing Commands to initiate WebServer in Instance Over SSH 
//  provisioner "remote-exec" {
  //   command = "firefox ${aws_instance.os1.public_ip}"
//}

