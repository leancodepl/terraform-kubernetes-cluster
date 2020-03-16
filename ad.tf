locals {
  secrets_end_date = "2020-06-10T12:00:00Z"
}

# Server app
resource "azuread_application" "server" {
  name            = "${var.name_prefix} AKS Server"
  homepage        = "https://server.${var.domain}"
  identifier_uris = ["https://server.${var.domain}"]
  reply_urls      = ["https://server.${var.domain}"]

  available_to_other_tenants = false
  group_membership_claims    = "All"

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" // Azure AD API

    resource_access {
      id   = "7ab1d382-f21e-4acd-a863-ba3e13f7da61" // Directory.Read.All
      type = "Role"
    }

    resource_access {
      id   = "06da0dbc-49e2-44d2-8312-53f166ab848a" // Directory.Read.All
      type = "Scope"
    }

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" // User.Read
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "server" {
  application_id = azuread_application.server.application_id
}

resource "random_string" "server_secret" {
  length = 64

  keepers = {
    app_id   = azuread_application.server.application_id
    end_date = local.secrets_end_date
  }
}

resource "azuread_service_principal_password" "server_secret" {
  service_principal_id = azuread_service_principal.server.id
  value                = random_string.server_secret.result
  end_date             = local.secrets_end_date
}

# Client app
resource "azuread_application" "client" {
  name = "${var.name_prefix} AKS Client"

  available_to_other_tenants = false
  type                       = "native"
  public_client              = true

  reply_urls = ["https://client.${var.domain}"]

  required_resource_access {
    resource_app_id = azuread_application.server.application_id

    resource_access {
      id   = [for p in azuread_application.server.oauth2_permissions : p.id if p.value == "user_impersonation"][0]
      type = "Scope"
    }
  }

  required_resource_access {
    resource_app_id = "00000002-0000-0000-c000-000000000000" // Azure AD API

    resource_access {
      id   = "311a71cc-e848-46a1-bdf8-97ff7156d8e6" // User.Read
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "client" {
  application_id = azuread_application.client.application_id
}

# Service account (mgmt for K8s)
resource "azuread_application" "service" {
  name            = "${var.name_prefix} AKS User"
  homepage        = "https://service.${var.domain}"
  identifier_uris = ["https://service.${var.domain}"]
  reply_urls      = ["https://service.${var.domain}"]
}

resource "azuread_service_principal" "service" {
  application_id = azuread_application.service.application_id
}

resource "random_string" "service_secret" {
  length = 64

  keepers = {
    app_id   = azuread_application.service.application_id
    end_date = local.secrets_end_date
  }
}

resource "azuread_service_principal_password" "service_secret" {
  service_principal_id = azuread_service_principal.service.id
  value                = random_string.service_secret.result
  end_date             = local.secrets_end_date
}

resource "azurerm_role_assignment" "service_contributor" {
  scope                = azurerm_resource_group.cluster.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.service.id
}
