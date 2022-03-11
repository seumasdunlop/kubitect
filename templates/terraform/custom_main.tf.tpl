#
# Configuration generated on: {{ now() }}
#

#================================
# Local variables
#================================

# Local variables used in many resources #
locals {
  config = yamldecode(file(pathexpand("{{ config_path }}")))
  ssh_pk_path = (try(local.config.cluster_nodeTemplate_ssh_privateKeyPath, null) != null
    ? pathexpand(local.config.cluster_nodeTemplate_ssh_privateKeyPath)
    : pathexpand("${path.module}/config/.ssh/id_rsa")
  )
  internal = {
    is_bridge = (local.config.cluster.network.mode == "bridge")
    vm_types = {
      load_balancer = "lb"
      master        = "master"
      worker        = "worker"
    }
  }
}


#=====================================================================================
# SSH Keys
#=====================================================================================

# Generates SSH keys if path to private key is not provided. #
resource "null_resource" "generate_ssh_keys" {

  count = try(local.config.cluster.nodeTemplate.ssh.privateKeyPath, null) == null ? 1 : 0

  provisioner "local-exec" {

    command = <<-EOF
      dirname $SSH_PK_PATH | xargs mkdir -p
      if [ ! -e $SSH_PK_PATH ] && [ ! -e $\{SSH_PK_PATH\}.pub ]; then \
        ssh-keygen -f $SSH_PK_PATH -q -N ""; \
      fi
    EOF

    environment = {
      SSH_PK_PATH = local.ssh_pk_path
    }
  }

}


#=====================================================================================
# Providers
#=====================================================================================
{# 
  Provider uri (localhost): "qemu:///system"
  Provider uri (remote): "qemu+ssh://<USER>@<IP>:<PORT>/system?keyfile=<PK_PATH>"
#}
{% for item in host_list %}
{% set ssh_pk_path = item.connection.ssh.keyfile if item.connection.ssh.keyfile is defined else keyfile_path %}
{% set ssh_pk_path = ssh_pk_path | replace("~", lookup('env', 'HOME')) %}

provider "libvirt" {
  alias = "{{ item.name }}"
{% if item.providerUri is defined %}
  uri   = "{{ item.providerUri }}"
{% elif item.connection.type in ["localhost", "local"] %}
  uri   = "qemu:///system"
{% else %}
  {% set provider_uri=[
    "qemu+ssh://",
    item.connection.user,
    "@",
    item.connection.ip,
    ":" ~ item.connection.ssh.port if item.connection.ssh.port is defined else "",
    "/system",
    "?keyfile=" ~ ssh_pk_path,
    "&no_verify=1" if item.connection.ssh.verify is defined and not item.connection.ssh.verify else ""
  ]-%} 
  uri   = "{{ provider_uri | join('') }}"
{% endif %}
}
{% endfor %}


#======================================================================================
# Modules
#======================================================================================

{# Check if default host is defined #}
{% set is_default_host_defined = [] -%}
{% for item in host_list -%}
  {%- if item.default is defined and item.default == true -%}
    {{ is_default_host_defined.append(true) }}
  {%- endif -%}
{% endfor %}
{% for item in host_list %}
{% set host_name = item.name %}
{% set resource_pool_path = item.resourcePoolPath if item.resourcePoolPath is defined else resource_pool_path %}
{% set is_default_host = item.default is defined and item.default == true or is_default_host_defined|length == 0 and loop.first == true %}
{% set default_selector = " || try(node.host, null) == null" if is_default_host else "" %}

module "main_{{ host_name }}" {

  source = "./modules/main"

  # General
  action = var.action

  # Libvirt
  libvirt_resource_pool_location = "{{ resource_pool_path }}"

  # General
  cluster_name                             = try(local.config.cluster.name, null)
  cluster_nodeTemplate_user                = try(local.config.cluster.nodeTemplate.user, null)
  cluster_nodeTemplate_ssh_privateKeyPath  = local.ssh_pk_path
  cluster_nodeTemplate_ssh_addToKnownHosts = try(local.config.cluster.nodeTemplate.ssh.addToKnownHosts, null)
  cluster_nodeTemplate_image_distro        = try(local.config.cluster.nodeTemplate.image.distro, null)
  cluster_nodeTemplate_image_source        = try(local.config.cluster.nodeTemplate.image.source, null)
  cluster_nodeTemplate_networkInterface    = try(local.config.cluster.nodeTemplate.networkInterface, null)
  cluster_nodeTemplate_updateOnBoot        = try(local.config.cluster.nodeTemplate.updateOnBoot, null)

  # Network configuration
  cluster_network_mode    = try(local.config.cluster.network.mode, null)
  cluster_network_cidr    = try(local.config.cluster.network.cidr, null)
  cluster_network_gateway = try(local.config.cluster.network.gateway, null)
  cluster_network_bridge  = try(local.config.cluster.network.bridge, null)
  cluster_network_dns     = try(local.config.cluster.network.dns, null)

  # HAProxy load balancer VMs parameters
  cluster_nodes_loadBalancer_vip             = try(local.config.cluster.nodes.loadBalancer.vip, null)
  cluster_nodes_loadBalancer_default_cpu     = try(local.config.cluster.nodes.loadBalancer.default.cpu, null)
  cluster_nodes_loadBalancer_default_ram     = try(local.config.cluster.nodes.loadBalancer.default.ram, null)
  cluster_nodes_loadBalancer_default_storage = try(local.config.cluster.nodes.loadBalancer.default.storage, null)
  cluster_nodes_loadBalancer_instances = [
    for node in try(local.config.cluster.nodes.loadBalancer.instances, []) :
    node if try(node.host, null) == "{{ host_name }}"{{ default_selector }}
  ]

  # Master node VMs parameters
  cluster_nodes_master_default_cpu     = try(local.config.cluster.nodes.master.default.cpu, null)
  cluster_nodes_master_default_ram     = try(local.config.cluster.nodes.master.default.ram, null)
  cluster_nodes_master_default_storage = try(local.config.cluster.nodes.master.default.storage, null)
  cluster_nodes_master_instances = [
    for node in try(local.config.cluster.nodes.master.instances, []) :
    node if try(node.host, null) == "{{ host_name }}"{{ default_selector }}
  ]

  # Worker node VMs parameters
  cluster_nodes_worker_default_cpu     = try(local.config.cluster.nodes.worker.default.cpu, null)
  cluster_nodes_worker_default_ram     = try(local.config.cluster.nodes.worker.default.ram, null)
  cluster_nodes_worker_default_storage = try(local.config.cluster.nodes.worker.default.storage, null)
  cluster_nodes_worker_default_label   = try(local.config.cluster.nodes.worker.default.label, null)
  cluster_nodes_worker_instances = [
    for node in try(local.config.cluster.nodes.worker.instances, []) :
    node if try(node.host, null) == "{{ host_name }}"{{ default_selector }}
  ]

  # Kubernetes & Kubespray
  kubernetes_version                     = try(local.config.kubernetes.version, null)
  kubernetes_networkPlugin               = try(local.config.kubernetes.networkPlugin, null)
  kubernetes_dnsMode                     = try(local.config.kubernetes.dnsMode, null)
  kubernetes_kubespray_url               = try(local.config.kubernetes.kubespray.url, null)
  kubernetes_kubespray_version           = try(local.config.kubernetes.kubespray.version, null)
  kubernetes_kubespray_addons_enabled    = false # try(local.config.kubernetes.kubespray.addons.enabled, null)
  kubernetes_kubespray_addons_configPath = ""    # try(local.config.kubernetes.kubespray.addons.configPath, null)
  kubernetes_other_copyKubeconfig        = try(local.config.kubernetes.other.copyKubeconfig, null)

  # Other
  internal = local.internal

  providers = {
    libvirt = libvirt.{{ host_name }}
  }

}
{% endfor %}


#================================
# Cluster
#================================
{# Creates a list of host modules. -#}
{% set host_name_list = [] -%}
{% for item in host_list -%}
  {{ host_name_list.append("module.main_"~item.name~".nodes") }}
{% endfor -%}
{% set host_name_list = host_name_list | join(', ') -%}

# Configures k8s cluster using Kubespray #
module "k8s_cluster" {

  source = "./modules/cluster"

  action = var.action

  # VM variables #
  vm_user            = try(local.config.cluster.nodeTemplate.user, null)
  vm_ssh_private_key = local.ssh_pk_path
  vm_distro          = try(local.config.cluster.nodeTemplate.image.distro, null)
  vm_network_interface = (local.internal.is_bridge
    ? local.config.cluster.network.bridge
    : local.config.cluster.nodeTemplate.networkInterface
  )

  worker_node_label = try(local.config.cluster.nodes.worker.default.label, null)
  lb_vip            = try(local.config.cluster.nodes.loadBalancer.vip, null)
  lb_nodes = [
    for node in flatten([{{ host_name_list }}]) :
    node if node.type == local.internal.vm_types.load_balancer
  ]
  master_nodes = [
    for node in flatten([{{ host_name_list }}]) :
    node if node.type == local.internal.vm_types.master
  ]
  worker_nodes = [
    for node in flatten([{{ host_name_list }}]) :
    node if node.type == local.internal.vm_types.worker
  ]

  # Kubernetes & Kubespray
  kubernetes_version                     = try(local.config.kubernetes.version, null)
  kubernetes_networkPlugin               = try(local.config.kubernetes.networkPlugin, null)
  kubernetes_dnsMode                     = try(local.config.kubernetes.dnsMode, null)
  kubernetes_kubespray_url               = try(local.config.kubernetes.kubespray.url, null)
  kubernetes_kubespray_version           = try(local.config.kubernetes.kubespray.version, null)
  kubernetes_kubespray_addons_enabled    = false # try(local.config.kubernetes.kubespray.addons.enabled, null)
  kubernetes_kubespray_addons_configPath = ""    # try(local.config.kubernetes.kubespray.addons.configPath, null)
  kubernetes_other_copyKubeconfig        = try(local.config.kubernetes.other.copyKubeconfig, null)

  # Other #
  #k8s_dashboard_rbac_enabled = var.k8s_dashboard_rbac_enabled
  #k8s_dashboard_rbac_user    = var.k8s_dashboard_rbac_user

  # K8s cluster creation depends on all VM modules #
  depends_on = [
{% for item in host_list %}
    module.main_{{ item.name }},
{% endfor %}
  ]
}