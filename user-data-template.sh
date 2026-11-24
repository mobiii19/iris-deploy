#!/bin/bash
# EC2 User Data: runs ONCE, as root, on the instance's first boot.
# All output is logged to /var/log/flask-app.log
set -x
exec > >(tee /var/log/flask-app.log) 2>&1

# ============ EDIT THESE TWO LINES ============
GITHUB_REPO="https://github.com/<your-username>/<your-repo>.git"
MODEL_BUCKET="ml-iris-model-<yourname>"
# ==============================================

apt-get update -y
apt-get install -y python3-pip python3-venv git

# Clone the application
cd /home/ubuntu
git clone "$GITHUB_REPO" app
cd app

# Build the virtual environment.
# --no-cache-dir keeps pip's memory use down on a 1 GB instance.
python3 -m venv venv
./venv/bin/pip install --no-cache-dir -r requirements.txt
chown -R ubuntu:ubuntu /home/ubuntu/app

# Ask the instance metadata service (IMDSv2) for this instance's ID,
# so /health can tell you which machine answered.
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

# Register the app as a systemd service so it starts on every boot,
# not just this one. This matters because Week 9 reuses this instance.
cat > /etc/systemd/system/flaskapp.service <<SERVICE
[Unit]
Description=Iris prediction API
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/app
Environment="MODEL_BUCKET=$MODEL_BUCKET"
Environment="INSTANCE_ID=$INSTANCE_ID"
ExecStart=/home/ubuntu/app/venv/bin/gunicorn --workers 2 --bind 0.0.0.0:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable flaskapp
systemctl start flaskapp

echo "User Data script finished"
