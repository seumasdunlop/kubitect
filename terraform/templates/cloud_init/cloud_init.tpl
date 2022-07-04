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

disk_setup:
  /dev/vdb:
    table_type: gpt
    layout: True
    overwrite: True

fs_setup:
  - device: /dev/vdb
    partition: 1
    filesystem: ext4

mounts:
  - [ /dev/vdb, /opt/data ]

ntp:
  enabled: true
  ntp_client: chrony  # Uses cloud-init default chrony configuration

packages:
  - qemu-guest-agent

runcmd:
  - [ systemctl, start, qemu-guest-agent.service ]
