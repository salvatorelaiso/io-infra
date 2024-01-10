locals {
  function_messages_cqrs = {
    app_settings = {
      FUNCTIONS_WORKER_RUNTIME       = "node"
      WEBSITE_RUN_FROM_PACKAGE       = "1"
      WEBSITE_DNS_SERVER             = "168.63.129.16"
      FUNCTIONS_WORKER_PROCESS_COUNT = 4
      NODE_ENV                       = "production"

      COSMOSDB_NAME              = "db"
      COSMOSDB_URI               = data.azurerm_cosmosdb_account.cosmos_api.endpoint
      COSMOSDB_KEY               = data.azurerm_cosmosdb_account.cosmos_api.primary_key
      COSMOSDB_CONNECTION_STRING = format("AccountEndpoint=%s;AccountKey=%s;", data.azurerm_cosmosdb_account.cosmos_api.endpoint, data.azurerm_cosmosdb_account.cosmos_api.primary_key)

      LEASE_COLLECTION_PREFIX = "bulk-status-update-00"

      MESSAGE_VIEW_UPDATE_FAILURE_QUEUE_NAME         = "message-view-update-failures"
      MESSAGE_VIEW_PAYMENT_UPDATE_FAILURE_QUEUE_NAME = "message-view-paymentupdate-failures"
      MESSAGE_PAYMENT_UPDATER_FAILURE_QUEUE_NAME     = "message-paymentupdater-failures"
      MESSAGE_CONTAINER_NAME                         = local.message_content_container_name
      MESSAGE_CONTENT_STORAGE_CONNECTION             = module.storage_api.primary_connection_string
      QueueStorageConnection                         = module.storage_api.primary_connection_string

      MESSAGE_STATUS_FOR_VIEW_TOPIC_CONSUMER_CONNECTION_STRING = module.event_hub.keys["io-cosmosdb-message-status-for-view.io-messages"].primary_connection_string
      MESSAGE_STATUS_FOR_VIEW_TOPIC_CONSUMER_GROUP             = "io-messages"
      MESSAGE_STATUS_FOR_VIEW_TOPIC_NAME                       = "io-cosmosdb-message-status-for-view"
      MESSAGE_STATUS_FOR_VIEW_TOPIC_PRODUCER_CONNECTION_STRING = module.event_hub.keys["io-cosmosdb-message-status-for-view.io-cdc"].primary_connection_string
      MESSAGE_STATUS_FOR_VIEW_BROKERS                          = "${local.io-p-evh-ns.hostname}:${local.io-p-evh-ns.port}"

      MESSAGE_CHANGE_FEED_LEASE_PREFIX = "CosmosApiMessageChangeFeed-00"
      // This must be expressed as a Timestamp
      // Saturday 1 July 2023 00:00:00
      MESSAGE_CHANGE_FEED_START_TIME = 1688169600000

      MESSAGES_TOPIC_CONNECTION_STRING = data.azurerm_eventhub_authorization_rule.io-p-messages-weu-prod01-evh-ns_messages_io-fn-messages-cqrs.primary_connection_string
      MESSAGES_TOPIC_NAME              = "messages"

      MESSAGE_STATUS_FOR_REMINDER_TOPIC_PRODUCER_CONNECTION_STRING = data.azurerm_eventhub_authorization_rule.io-p-messages-weu-prod01-evh-ns_message-status_io-fn-messages-cqrs.primary_connection_string
      MESSAGE_STATUS_FOR_REMINDER_TOPIC_NAME                       = "message-status"

      TARGETKAFKA_clientId        = "IO_FUNCTIONS_MESSAGES_CQRS"
      TARGETKAFKA_brokers         = "${local.io-p-messages-weu-prod01-evh-ns.hostname}:${local.io-p-messages-weu-prod01-evh-ns.port}"
      TARGETKAFKA_ssl             = "true"
      TARGETKAFKA_sasl_mechanism  = "plain"
      TARGETKAFKA_sasl_username   = "$ConnectionString"
      TARGETKAFKA_sasl_password   = data.azurerm_eventhub_authorization_rule.io-p-messages-weu-prod01-evh-ns_messages_io-fn-messages-cqrs.primary_connection_string
      TARGETKAFKA_idempotent      = "true"
      TARGETKAFKA_transactionalId = "IO_MESSAGES_CQRS"
      TARGETKAFKA_topic           = "messages"

      PAYMENT_FOR_VIEW_TOPIC_NAME                       = "payment-updates"
      PAYMENT_FOR_VIEW_TOPIC_CONSUMER_GROUP             = "$Default"
      PAYMENT_FOR_VIEW_TOPIC_CONSUMER_CONNECTION_STRING = data.azurerm_eventhub_authorization_rule.io-p-payments-weu-prod01-evh-ns_payment-updates_io-fn-messages-cqrs.primary_connection_string

      APIM_BASE_URL         = "https://${local.apim_hostname_api_app_internal}"
      APIM_SUBSCRIPTION_KEY = data.azurerm_key_vault_secret.apim_services_subscription_key.value

      PN_SERVICE_ID = var.pn_service_id
      // Keepalive fields are all optionals
      FETCH_KEEPALIVE_ENABLED             = "true"
      FETCH_KEEPALIVE_SOCKET_ACTIVE_TTL   = "110000"
      FETCH_KEEPALIVE_MAX_SOCKETS         = "40"
      FETCH_KEEPALIVE_MAX_FREE_SOCKETS    = "10"
      FETCH_KEEPALIVE_FREE_SOCKET_TIMEOUT = "30000"
      FETCH_KEEPALIVE_TIMEOUT             = "60000"
    }
  }
}

# Subnet to host fn messages cqrs function
module "function_messages_cqrs_snet" {
  source                                    = "git::https://github.com/pagopa/terraform-azurerm-v3.git//subnet?ref=v7.34.3"
  name                                      = format("%s-fn-messages-cqrs-snet", local.project)
  address_prefixes                          = var.cidr_subnet_fnmessagescqrs
  resource_group_name                       = azurerm_resource_group.rg_common.name
  virtual_network_name                      = module.vnet_common.name
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

#tfsec:ignore:azure-storage-queue-services-logging-enabled:exp:2022-05-01 # already ignored, maybe a bug in tfsec
module "function_messages_cqrs" {
  source = "git::https://github.com/pagopa/terraform-azurerm-v3.git//function_app?ref=v7.34.3"

  resource_group_name = azurerm_resource_group.backend_messages_rg.name
  name                = format("%s-messages-cqrs-fn", local.project)
  location            = var.location
  health_check_path   = "/api/v1/info"
  domain              = "MESSAGES"
  # Action groups for alerts
  action = [
    {
      action_group_id    = azurerm_monitor_action_group.error_action_group.id
      webhook_properties = null
    }
  ]

  storage_account_info = {
    account_kind                      = "StorageV2"
    account_tier                      = "Standard"
    account_replication_type          = "GZRS"
    access_tier                       = "Hot"
    advanced_threat_protection_enable = true
  }

  node_version                             = "18"
  runtime_version                          = "~4"
  always_on                                = var.function_messages_cqrs_always_on
  application_insights_instrumentation_key = azurerm_application_insights.application_insights.instrumentation_key

  app_service_plan_info = {
    kind                         = var.function_messages_cqrs_kind
    sku_tier                     = var.function_messages_cqrs_sku_tier
    sku_size                     = var.function_messages_cqrs_sku_size
    maximum_elastic_worker_count = 0
    worker_count                 = null
    zone_balancing_enabled       = null
  }

  app_settings = merge(
    local.function_messages_cqrs.app_settings, {
      // disable listeners on production slot
      "AzureWebJobs.CosmosApiMessageStatusChangeFeedForView.Disabled"     = "0"
      "AzureWebJobs.CosmosApiMessageStatusChangeFeedForReminder.Disabled" = "0"
      "AzureWebJobs.HandleMessageViewUpdateFailures.Disabled"             = "0"
      "AzureWebJobs.UpdateCosmosMessageView.Disabled"                     = "0"
      "AzureWebJobs.UpdatePaymentOnMessageView.Disabled"                  = "0"
      "AzureWebJobs.HandlePaymentUpdateFailures.Disabled"                 = "0"
      "AzureWebJobs.CosmosApiMessagesChangeFeed.Disabled"                 = "0"
      "AzureWebJobs.HandleMessageChangeFeedPublishFailures.Disabled"      = "0"
      "AzureWebJobs.CosmosApiChangeFeedForMessageRetention.Disabled"      = "1"
    }
  )

  subnet_id = module.function_messages_cqrs_snet.id

  internal_storage = {
    "enable"                     = true,
    "private_endpoint_subnet_id" = module.private_endpoints_subnet.id,
    "private_dns_zone_blob_ids"  = [azurerm_private_dns_zone.privatelink_blob_core.id],
    "private_dns_zone_queue_ids" = [azurerm_private_dns_zone.privatelink_queue_core.id],
    "private_dns_zone_table_ids" = [azurerm_private_dns_zone.privatelink_table_core.id],
    "queues" = [
      local.function_messages_cqrs.app_settings.MESSAGE_VIEW_UPDATE_FAILURE_QUEUE_NAME,
      format("%s-poison", local.function_messages_cqrs.app_settings.MESSAGE_VIEW_UPDATE_FAILURE_QUEUE_NAME),
      local.function_messages_cqrs.app_settings.MESSAGE_VIEW_PAYMENT_UPDATE_FAILURE_QUEUE_NAME,
      format("%s-poison", local.function_messages_cqrs.app_settings.MESSAGE_VIEW_PAYMENT_UPDATE_FAILURE_QUEUE_NAME),
      local.function_messages_cqrs.app_settings.MESSAGE_PAYMENT_UPDATER_FAILURE_QUEUE_NAME,
      format("%s-poison", local.function_messages_cqrs.app_settings.MESSAGE_PAYMENT_UPDATER_FAILURE_QUEUE_NAME)
    ],
    "containers"           = [],
    "blobs_retention_days" = 1,
  }

  allowed_subnets = [
    module.function_messages_cqrs_snet.id,
    module.apim_v2_snet.id,
  ]

  allowed_ips = concat(
    [],
    local.app_insights_ips_west_europe,
  )

  sticky_app_setting_names = [
    "AzureWebJobs.CosmosApiChangeFeedForMessageRetention.Disabled",
    "AzureWebJobs.CosmosApiMessageStatusChangeFeedForReminder.Disabled",
    "AzureWebJobs.CosmosApiMessageStatusChangeFeedForView.Disabled",
    "AzureWebJobs.CosmosApiMessagesChangeFeed.Disabled",
    "AzureWebJobs.HandleMessageChangeFeedPublishFailures.Disabled",
    "AzureWebJobs.HandleMessageViewUpdateFailures.Disabled",
    "AzureWebJobs.HandlePaymentUpdateFailures.Disabled",
    "AzureWebJobs.UpdateCosmosMessageView.Disabled",
    "AzureWebJobs.UpdatePaymentOnMessageView.Disabled"
  ]

  tags = var.tags
}

module "function_messages_cqrs_staging_slot" {
  source = "git::https://github.com/pagopa/terraform-azurerm-v3.git//function_app_slot?ref=v7.34.3"

  name                = "staging"
  location            = var.location
  resource_group_name = azurerm_resource_group.backend_messages_rg.name
  function_app_id     = module.function_messages_cqrs.id
  app_service_plan_id = module.function_messages_cqrs.app_service_plan_id
  health_check_path   = "/api/v1/info"

  storage_account_name               = module.function_messages_cqrs.storage_account.name
  storage_account_access_key         = module.function_messages_cqrs.storage_account.primary_access_key
  internal_storage_connection_string = module.function_messages_cqrs.storage_account_internal_function.primary_connection_string

  node_version                             = "18"
  runtime_version                          = "~4"
  always_on                                = var.function_messages_cqrs_always_on
  application_insights_instrumentation_key = azurerm_application_insights.application_insights.instrumentation_key

  app_settings = merge(
    local.function_messages_cqrs.app_settings, {
      // disable listeners on staging slot
      "AzureWebJobs.CosmosApiMessageStatusChangeFeedForView.Disabled"     = "1"
      "AzureWebJobs.CosmosApiMessageStatusChangeFeedForReminder.Disabled" = "1"
      "AzureWebJobs.HandleMessageViewUpdateFailures.Disabled"             = "1"
      "AzureWebJobs.UpdateCosmosMessageView.Disabled"                     = "1"
      "AzureWebJobs.UpdatePaymentOnMessageView.Disabled"                  = "1"
      "AzureWebJobs.HandlePaymentUpdateFailures.Disabled"                 = "1"
      "AzureWebJobs.CosmosApiMessagesChangeFeed.Disabled"                 = "1"
      "AzureWebJobs.HandleMessageChangeFeedPublishFailures.Disabled"      = "1"
      "AzureWebJobs.CosmosApiChangeFeedForMessageRetention.Disabled"      = "1"
    }
  )

  subnet_id = module.function_messages_cqrs_snet.id

  allowed_subnets = [
    module.function_messages_cqrs_snet.id,
    module.azdoa_snet[0].id,
  ]

  allowed_ips = concat(
    [],
  )

  tags = var.tags
}

resource "azurerm_monitor_autoscale_setting" "function_messages_cqrs" {
  name                = format("%s-autoscale", module.function_messages_cqrs.name)
  resource_group_name = azurerm_resource_group.backend_messages_rg.name
  location            = var.location
  target_resource_id  = module.function_messages_cqrs.app_service_plan_id

  profile {
    name = "default"

    capacity {
      default = var.function_messages_cqrs_autoscale_default
      minimum = var.function_messages_cqrs_autoscale_minimum
      maximum = var.function_messages_cqrs_autoscale_maximum
    }

    rule {
      metric_trigger {
        metric_name              = "Requests"
        metric_resource_id       = module.function_messages_cqrs.id
        metric_namespace         = "microsoft.web/sites"
        time_grain               = "PT1M"
        statistic                = "Average"
        time_window              = "PT5M"
        time_aggregation         = "Average"
        operator                 = "GreaterThan"
        threshold                = 3500
        divide_by_instance_count = false
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "2"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name              = "CpuPercentage"
        metric_resource_id       = module.function_messages_cqrs.app_service_plan_id
        metric_namespace         = "microsoft.web/serverfarms"
        time_grain               = "PT1M"
        statistic                = "Average"
        time_window              = "PT5M"
        time_aggregation         = "Average"
        operator                 = "GreaterThan"
        threshold                = 60
        divide_by_instance_count = false
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "2"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name              = "Requests"
        metric_resource_id       = module.function_messages_cqrs.id
        metric_namespace         = "microsoft.web/sites"
        time_grain               = "PT1M"
        statistic                = "Average"
        time_window              = "PT5M"
        time_aggregation         = "Average"
        operator                 = "LessThan"
        threshold                = 2500
        divide_by_instance_count = false
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT20M"
      }
    }

    rule {
      metric_trigger {
        metric_name              = "CpuPercentage"
        metric_resource_id       = module.function_messages_cqrs.app_service_plan_id
        metric_namespace         = "microsoft.web/serverfarms"
        time_grain               = "PT1M"
        statistic                = "Average"
        time_window              = "PT5M"
        time_aggregation         = "Average"
        operator                 = "LessThan"
        threshold                = 30
        divide_by_instance_count = false
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT20M"
      }
    }
  }
}
