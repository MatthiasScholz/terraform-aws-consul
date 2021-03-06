#!/bin/bash
# This script is meant to be run in the User Data of each EC2 Instance while it's booting. The script uses the
# run-consul script to configure and start Consul in client mode. Note that this script assumes it's running in an AMI
# built from the Packer template in examples/consul-ami/consul.json.

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# These variables are passed in via Terraform template interplation
/opt/consul/bin/run-consul --client --cluster-tag-key "${cluster_tag_key}" --cluster-tag-value "${cluster_tag_value}"

# Create service foo
cat << 'EOF' >> /opt/consul/config/serv_foo.json
{
 "service": {
    "name": "foo",
    "port": 8181,
    "connect": {
      "sidecar_service": {}
    }
  }
}
EOF

# Create service bar that is upstream to foo
cat << 'EOF' >> /opt/consul/config/serv_bar.json
{
 "service": {
    "name": "bar",
    "port": 8080,
    "connect": {
      "sidecar_service": {
        "proxy": {
          "upstreams": [
            {
              "destination_name": "foo",
              "local_bind_port": 9191
            }
          ]
        }  
      }
    }
  }
}
EOF

# Register both services foo & bar
consul services register /opt/consul/config/serv_foo.json
consul services register /opt/consul/config/serv_bar.json

# Start a proxy sidecar for service foo
nohup consul connect proxy -sidecar-for foo &>/dev/null &

# Start a proxy sidecar for service bar
nohup consul connect proxy -sidecar-for bar &>/dev/null &
