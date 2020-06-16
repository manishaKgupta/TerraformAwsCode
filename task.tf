	//AWS PROVIDER
provider "aws"{
	region="ap-south-1"
	shared_credentials_file = "C:/Users/Manisha/.aws/credentials"
	profile="manishag"
	      }
		//SECRET_KEY
variable "key_name" { default="my-key" }
resource "tls_private_key" "myterrakey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "private_key" {
    depends_on = [tls_private_key.myterrakey]
    content         =  tls_private_key.myterrakey.private_key_pem
    filename        =  "myinstancekey.pem"
    file_permission =  0400
}
resource "aws_key_pair" "generated_key" {
  key_name   = var.key_name
  public_key = tls_private_key.myterrakey.public_key_openssh
}
		//SECURITY GROUP
variable "prefix" {default="my-security"}
resource "aws_security_group" "ecs_http_access" {
  name        = var.prefix
  description = "HTTP SSH Access"
    ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP Access"
  	    }
    ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH Access"
            }
    egress  {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ALL Access"
 	   }
}
		//EC2 INSTANCE
resource "aws_instance" "myin" {
	ami = "ami-0447a12f28fddb066"
	instance_type="t2.micro"
	key_name=var.key_name
	security_groups=["my-security"]
	user_data= <<-EOF
		#! /bin/bash
		sudo su - root
		sudo yum install httpd -y
		sudo yum install git -y
		sudo systemctl start httpd
		sudo systemctl enable httpd
		sudo git clone https://github.com/manishaKgupta/myterra.git
		echo -e "o\nn\np\n1\n\n\nw" | fdisk /dev/sdd
		sudo mkfs.ext4 /dev/xvdd1
		sudo mount /dev/xvdd1 /var/www/html
		sudo cp -rf myterra/* /var/www/html
	EOF
	tags={
		Name= "Instance1"
	     }
}
		//EBS VOLUME
variable "ec2_device_names" { default = ["/dev/sdd"] }
variable "ec2_ebs_volume_count" { default = 1 }
resource "aws_ebs_volume" "ebs_volume" {
  availability_zone = aws_instance.myin.availability_zone
  size              = "1"
	}

resource "aws_volume_attachment" "volume_attachement" {
	depends_on = [ aws_ebs_volume.ebs_volume]
  	device_name = "/dev/sdd"
  	volume_id   = aws_ebs_volume.ebs_volume.id
  	instance_id = aws_instance.myin.id
  	force_detach= true
}
		//S3 BUCKET
resource "aws_s3_bucket" "mybucket" {
  bucket = "example1122558800"
  acl = "public-read"
  provisioner "local-exec" {
  command = "git clone https://github.com/manishaKgupta/myterra.git mycloneimage"
	}
	}
resource "aws_s3_bucket_object" "object" {
  depends_on = [aws_s3_bucket.mybucket]
  bucket = "example1122558800"
  acl = "public-read"
  key    = "mani.png"
  source = "C:/Users/Manisha/Desktop/terraform/Task1/mycloneimage/mani.png"
  content_type = "image/png"
	}
		//CLOUDFRONT DISTRIBUTION
resource "aws_cloudfront_distribution" "s3_cloudfront" {
    enabled       = true 
    viewer_certificate {
    cloudfront_default_certificate = true
     }
    default_cache_behavior {
        allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods   = ["GET", "HEAD"]
        target_origin_id = "s3-thisbucketisforterraform"
        forwarded_values {
            query_string = false
            cookies {
                forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
    }    
	restrictions {
        geo_restriction {
        restriction_type = "none"
        }
     }
    origin {
    domain_name = aws_s3_bucket.mybucket.bucket_domain_name
    origin_id   = "s3-thisbucketisforterraform"
         }
}
		//NULL RESOURCE
resource "null_resource" "myexecution" {
  connection {
        type     = "ssh"
        user     = "ec2-user"
	private_key = file("C:/Users/Manisha/Desktop/terraform/Task1/myinstancekey.pem")
        host     = aws_instance.myin.public_ip
     }
provisioner "remote-exec" {
inline = [
"sudo chmod -R 777 /var/www/html",
"sudo echo '<img src='https://${aws_cloudfront_distribution.s3_cloudfront.domain_name}/mani.png' width='250' height='250'>'  >> /var/www/html/indexfile.html" 
	] }
 }
