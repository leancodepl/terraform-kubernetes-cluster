variables {
  plugin = {
    prefix          = "tests"
    cluster_version = "1.34.2"
  }

  istio_version            = "1.28.3"
  install_gateway_api_crds = "install"

  compatibility = {
    kubernetes = {
      mode = "supported"
    }
    gateway_api = {
      mode = "enforced"
    }
  }
}

run "kubernetes_supported_passes" {
  command = plan

  plan_options {
    refresh = false
    target  = [terraform_data.kubernetes_compatibility_guard]
  }
}

run "kubernetes_incompatible_fails" {
  command = plan

  variables {
    istio_version = "1.27.3"
    compatibility = {
      kubernetes = {
        mode = "supported"
      }
      gateway_api = {
        mode = "skip"
      }
    }
  }

  plan_options {
    refresh = false
    target  = [terraform_data.kubernetes_compatibility_guard]
  }

  expect_failures = [terraform_data.kubernetes_compatibility_guard]
}

run "kubernetes_tested_mode_allows_tested_only_version" {
  command = plan

  variables {
    plugin = {
      prefix          = "tests"
      cluster_version = "1.29.0"
    }
    istio_version = "1.28.3"
    compatibility = {
      kubernetes = {
        mode = "tested"
      }
      gateway_api = {
        mode = "skip"
      }
    }
  }

  plan_options {
    refresh = false
    target  = [terraform_data.kubernetes_compatibility_guard]
  }
}

run "kubernetes_supported_rejects_tested_only_version" {
  command = plan

  variables {
    plugin = {
      prefix          = "tests"
      cluster_version = "1.29.0"
    }
    istio_version = "1.28.3"
    compatibility = {
      kubernetes = {
        mode = "supported"
      }
      gateway_api = {
        mode = "skip"
      }
    }
  }

  plan_options {
    refresh = false
    target  = [terraform_data.kubernetes_compatibility_guard]
  }

  expect_failures = [terraform_data.kubernetes_compatibility_guard]
}

run "kubernetes_skip_allows_incompatible" {
  command = plan

  variables {
    istio_version = "1.27.3"
    compatibility = {
      kubernetes = {
        mode = "skip"
      }
      gateway_api = {
        mode = "enforced"
      }
    }
  }

  plan_options {
    refresh = false
    target  = [terraform_data.gateway_api_compatibility_guard]
  }
}

run "gateway_override_too_high_fails" {
  command = plan

  variables {
    compatibility = {
      kubernetes = {
        mode = "skip"
      }
      gateway_api = {
        mode                 = "enforced"
        min_version_override = "v9.9.9"
      }
    }
  }

  plan_options {
    refresh = false
    target  = [terraform_data.gateway_api_compatibility_guard]
  }

  expect_failures = [terraform_data.gateway_api_compatibility_guard]
}

run "gateway_skip_allows_incompatible_override" {
  command = plan

  variables {
    compatibility = {
      kubernetes = {
        mode = "supported"
      }
      gateway_api = {
        mode                 = "skip"
        min_version_override = "v9.9.9"
      }
    }
  }

  plan_options {
    refresh = false
    target  = [terraform_data.kubernetes_compatibility_guard]
  }
}

run "gateway_override_does_not_need_args_fetch" {
  command = plan

  variables {
    istio_version = "9.9.9"
    compatibility = {
      kubernetes = {
        mode = "skip"
      }
      gateway_api = {
        mode                 = "enforced"
        min_version_override = "v1.0.0"
      }
    }
  }

  plan_options {
    refresh = false
    target  = [terraform_data.gateway_api_compatibility_guard]
  }
}

run "invalid_support_status_url_fails_validation" {
  command = plan

  variables {
    compatibility = {
      kubernetes = {
        mode               = "supported"
        support_status_url = "not-a-url"
      }
      gateway_api = {
        mode = "skip"
      }
    }
  }

  plan_options {
    refresh = false
    target  = [terraform_data.kubernetes_compatibility_guard]
  }

  expect_failures = [var.compatibility]
}
