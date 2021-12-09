provider "aws" {
  region  = var.region
  profile = var.aws_profile_name
}

// resource "aws_iam_role" "role" {
//   name = "EC2-CSYE6225"

//   assume_role_policy = <<-EOF
//     {
//       "Version": "2012-10-17",
//       "Statement": [
//         {
//           "Action": "sts:AssumeRole",
//           "Principal": {
//             "Service": "ec2.amazonaws.com"
//           },
//           "Effect": "Allow",
//           "Sid": ""
//         }
//       ]
//     }
// EOF
//   tags = {
//     Name = "CodeDeployEC2ServiceRole"
//   }
// }


data "aws_iam_role" "ec2Role" {
  name = "EC2-CSYE6225"
}

resource "aws_iam_instance_profile" "ec2Profile" {
  name = "ec2_profile"
  role = data.aws_iam_role.ec2Role.name
}

resource "aws_iam_role_policy" "CodeDeploy_EC2_S3" {
  name = "CodeDeployEC2S3"
  role = data.aws_iam_role.ec2Role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:Get*",
        "s3:List*",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:DeleteObjectVersion"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::codedeploy.csye6225saurabh.prod",
        "arn:aws:s3:::codedeploy.csye6225saurabh.prod/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ghActionUploadS3" {
  name   = "ghActionUploadS3"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                  "s3:Get*",
                  "s3:List*",
                  "s3:PutObject",
                  "s3:DeleteObject",
                  "s3:DeleteObjectVersion"
            ],
            "Resource": [
                "arn:aws:s3:::codedeploy.${var.aws_profile_name}.${var.domain_Name}",
                "arn:aws:s3:::codedeploy.${var.aws_profile_name}.${var.domain_Name}/*"
              ]
        }
    ]
}
EOF
}

# GH-Code-Deploy Policy for GitHub Actions to Call CodeDeploy
resource "aws_iam_policy" "GHCodeDeploy" {
  name   = "GH-Code-Deploy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:RegisterApplicationRevision",
        "codedeploy:GetApplicationRevision"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${local.aws_user_account_id}:application:${aws_codedeploy_app.codeDeployApplication.name}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:CreateDeployment",
        "codedeploy:GetDeployment"
      ],
      "Resource": [
         "arn:aws:codedeploy:${var.region}:${local.aws_user_account_id}:deploymentgroup:${aws_codedeploy_app.codeDeployApplication.name}/${aws_codedeploy_deployment_group.code_deploy_deployment_group.deployment_group_name}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:GetDeploymentConfig"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${local.aws_user_account_id}:deploymentconfig:CodeDeployDefault.OneAtATime",
        "arn:aws:codedeploy:${var.region}:${local.aws_user_account_id}:deploymentconfig:CodeDeployDefault.HalfAtATime",
        "arn:aws:codedeploy:${var.region}:${local.aws_user_account_id}:deploymentconfig:CodeDeployDefault.AllAtOnce"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "codeDeployRole" {
  name = "CodeDeployServiceRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ghactionsUserPolicy" {
  name   = "ghactions_user_policy"
  policy = <<-EOF
  {
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Action": [
          "ec2:AttachVolume",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CopyImage",
          "ec2:CreateImage",
          "ec2:CreateKeypair",
          "ec2:CreateSecurityGroup",
          "ec2:CreateSnapshot",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:DeleteKeyPair",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteSnapshot",
          "ec2:DeleteVolume",
          "ec2:DeregisterImage",
          "ec2:DescribeImageAttribute",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeRegions",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSnapshots",
          "ec2:DescribeSubnets",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DetachVolume",
          "ec2:GetPasswordData",
          "ec2:ModifyImageAttribute",
          "ec2:ModifyInstanceAttribute",
          "ec2:ModifySnapshotAttribute",
          "ec2:RegisterImage",
          "ec2:RunInstances",
          "ec2:StopInstances",
          "ec2:TerminateInstances"
        ],
        "Resource" : "*"
      }]
  }
  EOF

}

resource "aws_codedeploy_app" "codeDeployApplication" {
  compute_platform = "Server"
  name             = "csye6225-webapp"
}

data "aws_autoscaling_group" "autoscalingGroup" {
    name   = "autoscalingGroup"
} 


resource "aws_codedeploy_deployment_group" "code_deploy_deployment_group" {
  app_name               = aws_codedeploy_app.codeDeployApplication.name
  deployment_group_name  = "csye6225-webapp-deployment"
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  service_role_arn       = aws_iam_role.codeDeployRole.arn

  // ec2_tag_filter {
  //   key   = "Name"
  //   type  = "KEY_AND_VALUE"
  //   value = "Webapp"
  // }

  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
  autoscaling_groups = ["${data.aws_autoscaling_group.autoscalingGroup.name}"]
  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "Webapp"
    }
  }
  depends_on = [aws_codedeploy_app.codeDeployApplication]
}


data "aws_caller_identity" "current" {}

locals {
  aws_user_account_id = data.aws_caller_identity.current.account_id
}

# Attach the policy for CodeDeploy role for webapp
resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.codeDeployRole.name
}

resource "aws_iam_user_policy_attachment" "ghactions_ec2_policy_attach" {
  user       = "ghactions"
  policy_arn = aws_iam_policy.ghactionsUserPolicy.arn
}

resource "aws_iam_user_policy_attachment" "ghactions_s3_policy_attach" {
  user       = "ghactions"
  policy_arn = aws_iam_policy.ghActionUploadS3.arn
}


resource "aws_iam_user_policy_attachment" "ghactions_codedeploy_policy_attach" {
  user       = "ghactions"
  policy_arn = aws_iam_policy.GHCodeDeploy.arn
}

// data "aws_instance" "myinstance" {

//   filter {
//     name   = "tag:Name"
//     values = ["Webapp"]
//   }
// }


# add/update the DNS record api.dev.yourdomainname.tld. to the public IP address of the EC2 instance 
data "aws_route53_zone" "selected" {
  name         = "prod.${var.domain_Name}"
  private_zone = false
}

// resource "aws_route53_record" "www" {
//   zone_id = data.aws_route53_zone.selected.zone_id
//   name    = data.aws_route53_zone.selected.name
//   type    = "A"
//   ttl     = "60"
//   records = ["${data.aws_instance.myinstance.public_ip}"]
// }


data "aws_lb" "applicationLoadBalancer" {
  name = "applicationLoadBalancer"
}

resource "aws_route53_record" "www" {
  allow_overwrite = true
  zone_id = data.aws_route53_zone.selected.zone_id
  name = "${data.aws_route53_zone.selected.name}"
  type    = "A"
  alias {
    name                   = "${data.aws_lb.applicationLoadBalancer.dns_name}"
    zone_id                = "${data.aws_lb.applicationLoadBalancer.zone_id}"
    evaluate_target_health = true
  }

}
