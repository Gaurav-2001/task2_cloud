provider "aws" {
    region = "ap-south-1"
    profile = "gaurav"
}
resource "aws_security_group" "allow_http" {
  name        = "allow_http_ssh_nfs"
  description = "Allow http ssh & nfs inbound traffic"
  ingress{
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress{
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress{
    description = "NFS"
    from_port   = 2049
    to_port     = 2049
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
    Name = "allow_ssh_httpd_nfs_ingress"
  }
}
data "aws_vpc" "default" {
  default = true
}
data "aws_subnet" "subnets" {
  vpc_id            = "${data.aws_vpc.default.id}"
  availability_zone = "ap-south-1a"
}
resource "aws_efs_file_system" "efs_for_ec2" {
  creation_token = "efs_ec2"
  encrypted = false
  tags = {
    Name = "part_of_task_2"
  }
}
resource "aws_efs_mount_target" "target1" {
  file_system_id = "${aws_efs_file_system.efs_for_ec2.id}"
  subnet_id      = "${data.aws_subnet.subnets.id}"
}
resource "aws_instance"  "web01" {
  ami           = "ami-0732b62d310b80e97"
  instance_type = "t2.micro"
  key_name	= "mykey_ssh2"
  security_groups =  [ "allow_http_ssh_nfs" ] 
  tags = {
    Name = "Task2_with_efs"
  }
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/gaura/Desktop/mykey_ssh2.pem")
    host     = aws_instance.web01.public_ip
  }  
  provisioner "remote-exec" {
       inline = [
         "sudo yum install httpd php git net-tools  amazon-efs-utils -y",
         "sudo mount -t efs ${aws_efs_file_system.efs_for_ec2.id}:/ /var/www/html",
         "sudo systemctl start httpd",
         "sudo systemctl enable httpd",
      ]         
  }
}
resource "aws_s3_bucket" "cloudtask2" {
  bucket = "cloudtask2"
  acl    = "public-read"
  tags = {
    Name        = "s3_cloudfront"
    Environment = "Dev"
  }
  versioning {
    enabled = true
  }
}
output "domain_name" {
  value = aws_s3_bucket.cloudtask2.bucket_regional_domain_name
}
resource "aws_s3_bucket_object" "bucket_items" {
  key        = "image.jpg"
  bucket     = "${aws_s3_bucket.cloudtask2.id}"
  source     = "image.jpg"
  acl        = "public-read"
}
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
      domain_name = aws_s3_bucket.cloudtask2.bucket_regional_domain_name
      origin_id   = "s3-task2"
    }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "image used in webpage"
  default_root_object = "image.jpg"
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-task2"
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
  price_class = "PriceClass_All"
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
output "url" {
    value = "${aws_cloudfront_distribution.s3_distribution.domain_name}"
}
resource "null_resource" "nullremote-1"  {
	  connection {
	    type     = "ssh"
	    user     = "ec2-user"
	    private_key = file("C:/Users/gaura/Desktop/mykey_ssh2.pem")
	    host     = aws_instance.web01.public_ip
	  }
	provisioner "remote-exec" {
	    inline = [
	      "sudo rm -rf /var/www/html/*",
	      "sudo git clone https://github.com/Gaurav-2001/task1_cloud.git /var/www/html/"
	    ]
	  }
     provisioner "local-exec" {
        command = "chrome ${aws_instance.web01.public_ip}"
      }
	}
