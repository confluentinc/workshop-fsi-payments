#cloud-config
package_update: true
packages:
  - docker.io
  - jq
  - curl

runcmd:
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker ${admin_username} || true
  - mkdir -p /opt/shadowtraffic /opt/risk-api
  - chmod 777 /opt/shadowtraffic /opt/risk-api
