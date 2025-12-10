#!/bin/bash
# Install Apache and CloudWatch Agent
yum update -y
yum install -y httpd wget unzip

# Start httpd and add welcome page
systemctl enable httpd
systemctl start httpd
echo "TechNova Web Tier Active" > /var/www/html/index.html

# Install CloudWatch Agent (Amazon Linux 2)
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm -O /tmp/amazon-cloudwatch-agent.rpm
rpm -U /tmp/amazon-cloudwatch-agent.rpm || true

# Create CloudWatch agent config
cat > /opt/cwagentconfig.json <<'CWCFG'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}"
    },
    "metrics_collected": {
      "mem": { "measurement": ["mem_used_percent"], "metrics_collection_interval": 60 },
      "disk": { "measurement": ["used_percent"], "metrics_collection_interval": 60, "resources": ["/"] },
      "cpu": { "measurement": ["cpu_usage_idle","cpu_usage_iowait","cpu_usage_user"], "metrics_collection_interval": 60 },
      "net": { "measurement": ["bytes_sent","bytes_recv"], "metrics_collection_interval": 60 }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "${cw_log_group}",
            "log_stream_name": "{instance_id}-access",
            "timezone": "Local"
          },
          {
            "file_path": "/var/log/httpd/error_log",
            "log_group_name": "${cw_log_group}",
            "log_stream_name": "{instance_id}-error",
            "timezone": "Local"
          }
        ]
      }
    }
  }
}
CWCFG

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -c file:/opt/cwagentconfig.json -s || true
