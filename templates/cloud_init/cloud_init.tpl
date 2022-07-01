#cloud-config
preserve_hostname: false
hostname: ${hostname}

users:
  - name: ${user}
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    shell: /bin/bash
    ssh_authorized_keys:
      - ${ssh_public_key}

package_upgrade: ${update}

ntp:
  enabled: true
  ntp_client: chrony  # Uses cloud-init default chrony configuration

packages:
  - qemu-guest-agent
  - avahi-utils

runcmd:
  - [ systemctl, start, qemu-guest-agent.service ]
