#
# SECRETS
#

data "azurerm_key_vault_secret" "fn_app_PUBLIC_API_KEY" {
  name         = "apim-IO-SERVICE-KEY"
  key_vault_id = data.azurerm_key_vault.common.id
}

data "azurerm_key_vault_secret" "fn_app_SPID_LOGS_PUBLIC_KEY" {
  name         = "funcapp-KEY-SPIDLOGS-PUB"
  key_vault_id = data.azurerm_key_vault.common.id
}

data "azurerm_key_vault_secret" "fn_app_AZURE_NH_ENDPOINT" {
  name         = "common-AZURE-NH-ENDPOINT"
  key_vault_id = data.azurerm_key_vault.common.id
}

data "azurerm_key_vault_secret" "fn_app_beta_users" {
  name         = "io-fn-services-BETA-USERS" # reuse common beta list (array of CF)
  key_vault_id = data.azurerm_key_vault.common.id
}

data "azurerm_key_vault_secret" "ioweb_profile_function_api_key" {
  name         = "ioweb-profile-api-key"
  key_vault_id = data.azurerm_key_vault.ioweb_kv.id
}

#
# STORAGE
#

data "azurerm_storage_account" "iopstapp" {
  name                = "iopstapp"
  resource_group_name = local.rg_internal_name
}

#
# APP CONFIGURATION
#

locals {
  function_app = {
    app_settings_common = {
      FUNCTIONS_WORKER_RUNTIME       = "node"
      WEBSITE_RUN_FROM_PACKAGE       = "1"
      WEBSITE_DNS_SERVER             = "168.63.129.16"
      FUNCTIONS_WORKER_PROCESS_COUNT = 4
      NODE_ENV                       = "production"

      COSMOSDB_NAME              = "db"
      COSMOSDB_URI               = data.azurerm_cosmosdb_account.cosmos_api.endpoint
      COSMOSDB_KEY               = data.azurerm_cosmosdb_account.cosmos_api.primary_key
      COSMOSDB_CONNECTION_STRING = format("AccountEndpoint=%s;AccountKey=%s;", data.azurerm_cosmosdb_account.cosmos_api.endpoint, data.azurerm_cosmosdb_account.cosmos_api.primary_key)

      MESSAGE_CONTAINER_NAME = local.message_content_container_name
      QueueStorageConnection = data.azurerm_storage_account.storage_api.primary_connection_string

      // Keepalive fields are all optionals
      FETCH_KEEPALIVE_ENABLED             = "true"
      FETCH_KEEPALIVE_SOCKET_ACTIVE_TTL   = "110000"
      FETCH_KEEPALIVE_MAX_SOCKETS         = "40"
      FETCH_KEEPALIVE_MAX_FREE_SOCKETS    = "10"
      FETCH_KEEPALIVE_FREE_SOCKET_TIMEOUT = "30000"
      FETCH_KEEPALIVE_TIMEOUT             = "60000"

      LogsStorageConnection      = data.azurerm_storage_account.logs.primary_connection_string
      AssetsStorageConnection    = data.azurerm_storage_account.assets_cdn.primary_connection_string
      STATUS_ENDPOINT_URL        = "https://api-app.io.pagopa.it/info"
      STATUS_REFRESH_INTERVAL_MS = "300000"

      // TODO: Rename to SUBSCRIPTIONSFEEDBYDAY_TABLE_NAME
      SUBSCRIPTIONS_FEED_TABLE = "SubscriptionsFeedByDay"
      MAIL_FROM                = "IO - l'app dei servizi pubblici <no-reply@io.italia.it>"
      DPO_EMAIL_ADDRESS        = "dpo@pagopa.it"
      PUBLIC_API_URL           = local.service_api_url
      FUNCTIONS_PUBLIC_URL     = "https://api.io.pagopa.it/public"

      // Push notifications
      AZURE_NH_HUB_NAME                       = "io-p-ntf-common"
      NOTIFICATIONS_QUEUE_NAME                = local.storage_account_notifications_queue_push_notifications
      NOTIFICATIONS_STORAGE_CONNECTION_STRING = data.azurerm_storage_account.notifications.primary_connection_string

      // Service Preferences Migration Queue
      MIGRATE_SERVICES_PREFERENCES_PROFILE_QUEUE_NAME = "profile-migrate-services-preferences-from-legacy"
      FN_APP_STORAGE_CONNECTION_STRING                = data.azurerm_storage_account.iopstapp.primary_connection_string

      // Events configs
      EventsQueueStorageConnection = data.azurerm_storage_account.storage_apievents.primary_connection_string
      EventsQueueName              = "events" # reference to https://github.com/pagopa/io-infra/blob/12a2f3bffa49dab481990fccc9f2a904004862ec/src/core/storage_apievents.tf#L7

      // Disable functions
      "AzureWebJobs.StoreSpidLogs.Disabled"            = "1"
      "AzureWebJobs.HandleNHNotificationCall.Disabled" = "1"

      BETA_USERS = data.azurerm_key_vault_secret.fn_app_beta_users.value
      # Enable use of templated email
      FF_TEMPLATE_EMAIL = "ALL"
      # Cashback welcome message
      IS_CASHBACK_ENABLED = "false"
      # Only national service
      FF_ONLY_NATIONAL_SERVICES = "true"
      # Limit the number of local services
      FF_LOCAL_SERVICES_LIMIT = "0"
      # eucovidcert configs
      FF_NEW_USERS_EUCOVIDCERT_ENABLED       = "true"
      EUCOVIDCERT_PROFILE_CREATED_QUEUE_NAME = "eucovidcert-profile-created"

      OPT_OUT_EMAIL_SWITCH_DATE = local.opt_out_email_switch_date
      FF_OPT_IN_EMAIL_ENABLED   = local.ff_opt_in_email_enabled

      VISIBLE_SERVICE_BLOB_ID = "visible-services-national.json"

      # Login Email variables
      MAGIC_LINK_SERVICE_API_KEY    = data.azurerm_key_vault_secret.ioweb_profile_function_api_key.value
      MAGIC_LINK_SERVICE_PUBLIC_URL = format("https://%s-%s-%s-ioweb-profile-fn.azurewebsites.net", var.prefix, var.env_short, var.location_short)
      IOWEB_ACCESS_REF              = "https://ioapp.it"
      #

      # UNIQUE EMAIL ENFORCEMENT
      FF_UNIQUE_EMAIL_ENFORCEMENT             = "ALL"
      UNIQUE_EMAIL_ENFORCEMENT_USERS          = jsonencode(split(",", data.azurerm_key_vault_secret.app_backend_UNIQUE_EMAIL_ENFORCEMENT_USER.value))
      PROFILE_EMAIL_STORAGE_CONNECTION_STRING = data.azurerm_storage_account.citizen_auth_common.primary_connection_string
      PROFILE_EMAIL_STORAGE_TABLE_NAME        = "profileEmails"
      ON_PROFILE_UPDATE_LEASES_PREFIX         = "OnProfileUpdateLeasesPrefix-001"

      MAILUP_USERNAME      = data.azurerm_key_vault_secret.common_MAILUP_USERNAME.value
      MAILUP_SECRET        = data.azurerm_key_vault_secret.common_MAILUP_SECRET.value
      PUBLIC_API_KEY       = trimspace(data.azurerm_key_vault_secret.fn_app_PUBLIC_API_KEY.value)
      SPID_LOGS_PUBLIC_KEY = trimspace(data.azurerm_key_vault_secret.fn_app_SPID_LOGS_PUBLIC_KEY.value)
      AZURE_NH_ENDPOINT    = data.azurerm_key_vault_secret.fn_app_AZURE_NH_ENDPOINT.value
    }
    app_settings_1 = {
    }
    app_settings_2 = {
    }

    #List of the functions'name to be disabled in both prod and slot
    functions_disabled = [
      "OnProfileUpdate"
    ]
  }
}

resource "azurerm_resource_group" "app_rg" {
  count    = var.function_app_count
  name     = format("%s-app-rg-%d", local.project, count.index + 1)
  location = var.location

  tags = var.tags
}

# Subnet to host app function
module "app_snet" {
  count                                     = var.function_app_count
  source                                    = "git::https://github.com/pagopa/terraform-azurerm-v3.git//subnet?ref=v7.61.0"
  name                                      = format("%s-app-snet-%d", local.project, count.index + 1)
  address_prefixes                          = [var.cidr_subnet_app[count.index]]
  resource_group_name                       = local.rg_common_name
  virtual_network_name                      = local.vnet_common_name
  private_endpoint_network_policies_enabled = false

  service_endpoints = [
    "Microsoft.Web",
    "Microsoft.AzureCosmosDB",
    "Microsoft.Storage",
  ]

  delegation = {
    name = "default"
    service_delegation = {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# subnet for session-manager
data "azurerm_subnet" "session_manager_snet" {
  name                 = format("%s-weu-session-manager-snet-02", local.project)
  virtual_network_name = format("%s-vnet-common", local.project)
  resource_group_name  = local.rg_common_name
}

#tfsec:ignore:azure-storage-queue-services-logging-enabled:exp:2022-05-01 # already ignored, maybe a bug in tfsec
module "function_app" {
  count  = var.function_app_count
  source = "git::https://github.com/pagopa/terraform-azurerm-v3.git//function_app?ref=v7.61.0"

  resource_group_name = azurerm_resource_group.app_rg[count.index].name
  name                = format("%s-app-fn-%d", local.project, count.index + 1)
  location            = var.location
  health_check_path   = "/api/v1/info"

  node_version    = "18"
  runtime_version = "~4"

  always_on                                = "true"
  application_insights_instrumentation_key = data.azurerm_application_insights.application_insights.instrumentation_key

  app_service_plan_info = {
    kind                         = var.function_app_kind
    sku_tier                     = var.function_app_sku_tier
    sku_size                     = var.function_app_sku_size
    maximum_elastic_worker_count = 0
    worker_count                 = null
    zone_balancing_enabled       = null
  }

  app_settings = merge(
    local.function_app.app_settings_common,
    {
      # Disabled functions on slot triggered by cosmosDB change feed
      for to_disable in local.function_app.functions_disabled :
      format("AzureWebJobs.%s.Disabled", to_disable) => "1"
    }
  )

  internal_storage = {
    "enable"                     = true,
    "private_endpoint_subnet_id" = data.azurerm_subnet.private_endpoints_subnet.id,
    "private_dns_zone_blob_ids"  = [data.azurerm_private_dns_zone.privatelink_blob_core.id],
    "private_dns_zone_queue_ids" = [data.azurerm_private_dns_zone.privatelink_queue_core.id],
    "private_dns_zone_table_ids" = [data.azurerm_private_dns_zone.privatelink_table_core.id],
    "queues"                     = [],
    "containers"                 = [],
    "blobs_retention_days"       = 1,
  }

  subnet_id = module.app_snet[count.index].id

  allowed_subnets = [
    module.app_snet[count.index].id,
    data.azurerm_subnet.app_backendl1_snet.id,
    data.azurerm_subnet.app_backendl2_snet.id,
    data.azurerm_subnet.app_backendli_snet.id,
    data.azurerm_subnet.ioweb_profile_snet.id,
    data.azurerm_subnet.session_manager_snet.id,
  ]

  sticky_app_setting_names = concat([
    "AzureWebJobs.HandleNHNotificationCall.Disabled",
    "AzureWebJobs.StoreSpidLogs.Disabled"
    ],
    [
      for to_disable in local.function_app.functions_disabled :
      format("AzureWebJobs.%s.Disabled", to_disable)
    ]
  )

  tags = var.tags
}

module "function_app_staging_slot" {
  count  = var.function_app_count
  source = "git::https://github.com/pagopa/terraform-azurerm-v3.git//function_app_slot?ref=v7.61.0"

  name                = "staging"
  location            = var.location
  resource_group_name = azurerm_resource_group.app_rg[count.index].name
  function_app_id     = module.function_app[count.index].id
  app_service_plan_id = module.function_app[count.index].app_service_plan_id
  health_check_path   = "/api/v1/info"

  storage_account_name               = module.function_app[count.index].storage_account.name
  storage_account_access_key         = module.function_app[count.index].storage_account.primary_access_key
  internal_storage_connection_string = module.function_app[count.index].storage_account_internal_function.primary_connection_string

  node_version                             = "18"
  always_on                                = "true"
  runtime_version                          = "~4"
  application_insights_instrumentation_key = data.azurerm_application_insights.application_insights.instrumentation_key

  app_settings = merge(
    local.function_app.app_settings_common,
    {
      # Disabled functions on slot triggered by cosmosDB change feed
      for to_disable in local.function_app.functions_disabled :
      format("AzureWebJobs.%s.Disabled", to_disable) => "1"
    }
  )

  subnet_id = module.app_snet[count.index].id

  allowed_subnets = [
    module.app_snet[count.index].id,
    data.azurerm_subnet.azdoa_snet.id,
    data.azurerm_subnet.app_backendl1_snet.id,
    data.azurerm_subnet.app_backendl2_snet.id,
    data.azurerm_subnet.app_backendli_snet.id,
  ]

  tags = var.tags
}

resource "azurerm_monitor_autoscale_setting" "function_app" {
  count               = var.function_app_count
  name                = format("%s-autoscale", module.function_app[count.index].name)
  resource_group_name = azurerm_resource_group.app_rg[count.index].name
  location            = var.location
  target_resource_id  = module.function_app[count.index].app_service_plan_id

  dynamic "profile" {
    for_each = [
      {
        name = "{\"name\":\"default\",\"for\":\"evening\"}",

        recurrence = {
          hours   = 22
          minutes = 59
        }

        capacity = {
          default = 10
          minimum = 3
          maximum = 30
        }
      },
      {
        name = "{\"name\":\"default\",\"for\":\"night\"}",

        recurrence = {
          hours   = 5
          minutes = 0
        }

        capacity = {
          default = 10
          minimum = 3
          maximum = 30
        }
      },
      {
        name = "evening"

        recurrence = {
          hours   = 19
          minutes = 30
        }

        capacity = {
          default = 10
          minimum = 4
          maximum = 30
        }
      },
      {
        name = "night"

        recurrence = {
          hours   = 23
          minutes = 0
        }

        capacity = {
          default = 10
          minimum = 2
          maximum = 30
        }
      }
    ]
    iterator = profile_info

    content {
      name = profile_info.value.name

      dynamic "recurrence" {
        for_each = profile_info.value.recurrence != null ? [profile_info.value.recurrence] : []
        iterator = recurrence_info

        content {
          timezone = "W. Europe Standard Time"
          hours    = [recurrence_info.value.hours]
          minutes  = [recurrence_info.value.minutes]
          days = [
            "Monday",
            "Tuesday",
            "Wednesday",
            "Thursday",
            "Friday",
            "Saturday",
            "Sunday"
          ]
        }
      }

      capacity {
        default = profile_info.value.capacity.default
        minimum = profile_info.value.capacity.minimum
        maximum = profile_info.value.capacity.maximum
      }

      rule {
        metric_trigger {
          metric_name              = "Requests"
          metric_resource_id       = module.function_app[count.index].id
          metric_namespace         = "microsoft.web/sites"
          time_grain               = "PT1M"
          statistic                = "Max"
          time_window              = "PT2M"
          time_aggregation         = "Maximum"
          operator                 = "GreaterThan"
          threshold                = 2000
          divide_by_instance_count = true
        }

        scale_action {
          direction = "Increase"
          type      = "ChangeCount"
          value     = "2"
          cooldown  = "PT1M"
        }
      }

      rule {
        metric_trigger {
          metric_name              = "CpuPercentage"
          metric_resource_id       = module.function_app[count.index].app_service_plan_id
          metric_namespace         = "microsoft.web/serverfarms"
          time_grain               = "PT1M"
          statistic                = "Max"
          time_window              = "PT1M"
          time_aggregation         = "Maximum"
          operator                 = "GreaterThan"
          threshold                = 40
          divide_by_instance_count = false
        }

        scale_action {
          direction = "Increase"
          type      = "ChangeCount"
          value     = "4"
          cooldown  = "PT1M"
        }
      }

      rule {
        metric_trigger {
          metric_name              = "Requests"
          metric_resource_id       = module.function_app[count.index].id
          metric_namespace         = "microsoft.web/sites"
          time_grain               = "PT1M"
          statistic                = "Average"
          time_window              = "PT5M"
          time_aggregation         = "Average"
          operator                 = "LessThan"
          threshold                = 200
          divide_by_instance_count = true
        }

        scale_action {
          direction = "Decrease"
          type      = "ChangeCount"
          value     = "1"
          cooldown  = "PT1M"
        }
      }

      rule {
        metric_trigger {
          metric_name              = "CpuPercentage"
          metric_resource_id       = module.function_app[count.index].app_service_plan_id
          metric_namespace         = "microsoft.web/serverfarms"
          time_grain               = "PT1M"
          statistic                = "Average"
          time_window              = "PT5M"
          time_aggregation         = "Average"
          operator                 = "LessThan"
          threshold                = 15
          divide_by_instance_count = false
        }

        scale_action {
          direction = "Decrease"
          type      = "ChangeCount"
          value     = "1"
          cooldown  = "PT2M"
        }
      }
    }
  }
}

## Alerts

resource "azurerm_monitor_metric_alert" "function_app_health_check" {
  count = var.function_app_count

  name                = "${module.function_app[count.index].name}-health-check-failed"
  resource_group_name = azurerm_resource_group.app_rg[count.index].name
  scopes              = [module.function_app[count.index].id]
  description         = "${module.function_app[count.index].name} health check failed"
  severity            = 1
  frequency           = "PT5M"
  auto_mitigate       = false

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "HealthCheckStatus"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 50
  }

  action {
    action_group_id = data.azurerm_monitor_action_group.error_action_group.id
  }
}
