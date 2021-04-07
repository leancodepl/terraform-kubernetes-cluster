# Service account (mgmt for K8s)
resource "azuread_application" "service" {
  display_name    = "${var.name_prefix} AKS User"
  homepage        = "https://service.${var.domain}"
  identifier_uris = ["https://service.${var.domain}"]
  reply_urls      = ["https://service.${var.domain}"]
}

resource "azuread_service_principal" "service" {
  application_id = azuread_application.service.application_id
}

resource "random_password" "service_secret" {
  length = 64

  keepers = {
    app_id   = azuread_application.service.application_id
    end_date = var.ad_config.service_secret_end_date
  }
}

resource "azuread_service_principal_password" "service_secret" {
  service_principal_id = azuread_service_principal.service.id
  value                = random_password.service_secret.result
  end_date             = var.ad_config.service_secret_end_date
}

resource "azurerm_role_assignment" "service_contributor" {
  scope                = azurerm_resource_group.cluster.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.service.id
}
