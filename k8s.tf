resource "azurerm_kubernetes_cluster" "cluster" {
  name                = "${var.prefix}-k8s-cluster"
  resource_group_name = azurerm_resource_group.cluster.name
  location            = azurerm_resource_group.cluster.location

  dns_prefix         = var.prefix
  kubernetes_version = var.cluster_config.version

  default_node_pool {
    name = "default"

    vm_size             = var.cluster_config.default_pool.vm_size
    os_disk_size_gb     = var.cluster_config.default_pool.os_disk_size_gb
    max_pods            = var.cluster_config.default_pool.max_pods
    enable_auto_scaling = var.cluster_config.default_pool.enable_auto_scaling

    min_count  = var.cluster_config.default_pool.enable_auto_scaling ? var.cluster_config.default_pool.min_count : null
    max_count  = var.cluster_config.default_pool.enable_auto_scaling ? var.cluster_config.default_pool.max_count : null
    node_count = var.cluster_config.default_pool.enable_auto_scaling ? null : var.cluster_config.default_pool.count

    vnet_subnet_id = azurerm_subnet.node_pool.id

    orchestrator_version = var.cluster_config.default_pool.version
    node_taints          = var.cluster_config.default_pool.node_taints

    type = "VirtualMachineScaleSets"
  }

  service_principal {
    client_id     = azuread_service_principal.service.application_id
    client_secret = random_password.service_secret.result
  }

  role_based_access_control {
    enabled = true

    azure_active_directory {
      client_app_id     = azuread_application.client.application_id
      server_app_id     = azuread_application.server.application_id
      server_app_secret = random_password.server_secret.result
    }
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = var.cluster_config.network_policy
    load_balancer_sku = var.cluster_config.loadbalancer

    # Totally outside the 10.X.X.X that we use internally
    docker_bridge_cidr = "172.17.0.1/16"
    service_cidr       = "10.255.0.0/16"
    dns_service_ip     = "10.255.0.10"
  }

  addon_profile {
    oms_agent {
      enabled = false
    }

    kube_dashboard {
      enabled = false
    }

    azure_policy {
      enabled = var.cluster_config.network_policy != null
    }

    http_application_routing {
      enabled = false
    }

    aci_connector_linux {
      enabled = false
    }
  }

  api_server_authorized_ip_ranges = var.cluster_config.access.authorized_ip_ranges

  tags = local.tags

  depends_on = [
    azuread_service_principal_password.server_secret,
    azuread_service_principal_password.service_secret,
    azuread_service_principal.client,
    azurerm_role_assignment.service_contributor
  ]
}
