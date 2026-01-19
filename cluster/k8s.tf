resource "azurerm_kubernetes_cluster" "cluster" {
  name                = "${var.prefix}-k8s-cluster"
  resource_group_name = azurerm_resource_group.cluster.name
  location            = azurerm_resource_group.cluster.location

  dns_prefix         = var.prefix
  kubernetes_version = var.cluster_version
  sku_tier           = var.sku_tier

  default_node_pool {
    name = "default"

    vm_size              = var.default_pool.vm_size
    os_disk_size_gb      = var.default_pool.os_disk_size_gb
    max_pods             = var.default_pool.max_pods
    auto_scaling_enabled = var.default_pool.auto_scaling_enabled

    min_count  = var.default_pool.min_count
    max_count  = var.default_pool.max_count
    node_count = var.default_pool.count

    vnet_subnet_id = azurerm_subnet.default_node_pool.id

    orchestrator_version = var.default_pool.version == null ? var.cluster_version : var.default_pool.version

    type = "VirtualMachineScaleSets"

    upgrade_settings {
      drain_timeout_in_minutes      = 10
      node_soak_duration_in_minutes = 0
      max_surge                     = 10
    }

    tags = local.tags
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cluster_identity.id]
  }

  azure_active_directory_role_based_access_control {
    admin_group_object_ids = [var.access.admin_access_group]
    azure_rbac_enabled     = false
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = var.network.network_policy
    load_balancer_sku = var.network.load_balancer_sku

    # Totally outside the 10.X.X.X that we use internally
    service_cidr   = "10.255.0.0/16"
    dns_service_ip = "10.255.0.10"
  }

  azure_policy_enabled             = var.network.network_policy != null
  http_application_routing_enabled = false
  oidc_issuer_enabled              = true
  workload_identity_enabled        = true

  image_cleaner_interval_hours = 48
  node_os_upgrade_channel      = var.node_os_upgrade_channel

  dynamic "maintenance_window_auto_upgrade" {
    for_each = var.maintenance_window_auto_upgrade[*]
    content {
      interval     = maintenance_window_auto_upgrade.value.interval
      duration     = maintenance_window_auto_upgrade.value.duration
      frequency    = maintenance_window_auto_upgrade.value.frequency
      day_of_week  = maintenance_window_auto_upgrade.value.day_of_week
      day_of_month = maintenance_window_auto_upgrade.value.day_of_month
      start_date   = maintenance_window_auto_upgrade.value.start_date
      start_time   = maintenance_window_auto_upgrade.value.start_time
      utc_offset   = maintenance_window_auto_upgrade.value.utc_offset
      week_index   = maintenance_window_auto_upgrade.value.week_index
      dynamic "not_allowed" {
        for_each = maintenance_window_auto_upgrade.value.not_allowed[*]
        content {
          start = maintenance_window_auto_upgrade.value.not_allowed.start
          end   = maintenance_window_auto_upgrade.value.not_allowed.end
        }
      }
    }
  }

  dynamic "maintenance_window_node_os" {
    for_each = var.maintenance_window_node_os[*]
    content {
      interval     = maintenance_window_node_os.value.interval
      duration     = maintenance_window_node_os.value.duration
      frequency    = maintenance_window_node_os.value.frequency
      day_of_week  = maintenance_window_node_os.value.day_of_week
      day_of_month = maintenance_window_node_os.value.day_of_month
      start_date   = maintenance_window_node_os.value.start_date
      start_time   = maintenance_window_node_os.value.start_time
      utc_offset   = maintenance_window_node_os.value.utc_offset
      week_index   = maintenance_window_node_os.value.week_index
      dynamic "not_allowed" {
        for_each = maintenance_window_node_os.value.not_allowed[*]
        content {
          start = maintenance_window_node_os.value.not_allowed.start
          end   = maintenance_window_node_os.value.not_allowed.end
        }
      }
    }
  }

  tags = local.tags

  # Do not remove! Once set, upgrade_override block cannot be removed from state.
  upgrade_override {
    force_upgrade_enabled = false
  }

  depends_on = [
    azurerm_role_assignment.service_contributor
  ]

  lifecycle {
    ignore_changes = [
      # See: https://github.com/hashicorp/terraform-provider-azurerm/issues/28960
      upgrade_override[0].effective_until
    ] 
  }
}

data "azurerm_resource_group" "cluster_node_group" {
  name = azurerm_kubernetes_cluster.cluster.node_resource_group
}

