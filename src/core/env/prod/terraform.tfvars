env_short = "p"

tags = {
  CreatedBy   = "Terraform"
  Environment = "Prod"
  Owner       = "IO"
  Source      = "https://github.com/pagopa/io-infra"
  CostCenter  = "TS310 - PAGAMENTI & SERVIZI"
}

location       = "westeurope"
location_short = "weu"

# dns
external_domain              = "pagopa.it"
dns_zone_io                  = "io"
dns_zone_io_selfcare         = "io.selfcare"
dns_zone_firmaconio_selfcare = "firmaconio.selfcare"

lock_enable = true

common_rg = "io-p-rg-common"

# networking
vnet_name = "io-p-vnet-common"
ddos_protection_plan = {
  id     = "/subscriptions/0da48c97-355f-4050-a520-f11a18b8be90/resourceGroups/sec-p-ddos/providers/Microsoft.Network/ddosProtectionPlans/sec-p-ddos-protection"
  enable = true
}
cidr_common_vnet     = ["10.0.0.0/16"]
cidr_common_in_vnet  = ["10.20.0.0/16"]
cidr_weu_beta_vnet   = ["10.10.0.0/16"]
cidr_weu_prod01_vnet = ["10.11.0.0/16"]
cidr_weu_prod02_vnet = ["10.12.0.0/16"]
# check free subnet on azure portal io-p-vnet-common -> subnets
cidr_subnet_eventhub                       = ["10.0.10.0/24"]
cidr_subnet_fnelt                          = ["10.0.11.0/24"]
cidr_subnet_appgateway                     = ["10.0.13.0/24"]
cidr_subnet_redis_apim                     = ["10.0.14.0/24"]
cidr_subnet_fnadmin                        = ["10.0.15.0/26"]
cidr_subnet_shared_1                       = ["10.0.16.0/26"]
cidr_subnet_fnlollipop                     = ["10.0.17.0/26"]
cidr_subnet_fnfastlogin                    = ["10.0.17.128/26"]
cidr_subnet_apim                           = ["10.0.101.0/24"]
cidr_subnet_apim_v2                        = ["10.0.100.0/24"]
cidr_subnet_fncdnassets                    = ["10.0.131.0/24"]
cidr_subnet_app                            = ["10.0.132.0/26", "10.0.132.64/26"]
cidr_subnet_app_async                      = ["10.0.132.128/26"]
cidr_subnet_vpn                            = ["10.0.133.0/24"]
cidr_subnet_selfcare_be                    = ["10.0.137.0/24"]
cidr_subnet_devportalservicedata_db_server = ["10.0.138.0/24"]
cidr_subnet_services                       = ["10.0.139.0/26", "10.0.139.64/26"]
# new push notif is related to messages domain ###############
##############################################################
cidr_subnet_appbackendl1 = ["10.0.152.0/24"]
cidr_subnet_appbackendl2 = ["10.0.153.0/24"]
cidr_subnet_appbackendli = ["10.0.154.0/24"]
cidr_subnet_redis_common = ["10.0.200.0/24"]
cidr_subnet_pendpoints   = ["10.0.240.0/23"]
cidr_subnet_azdoa        = ["10.0.250.0/24"]
cidr_subnet_dnsforwarder = ["10.0.252.8/29"]

# just for reminder: declared in https://github.com/pagopa/io-infra/blob/main/src/domains/ioweb-app/env/weu-prod01/terraform.tfvars
# subnet for ioweb_profile -> cidr_subnet_fniowebprofile = ["10.0.117.0/24"]

## REDIS COMMON ##
redis_common = {
  capacity                      = 2
  shard_count                   = 4
  family                        = "P"
  sku_name                      = "Premium"
  public_network_access_enabled = true
  rdb_backup_enabled            = true
  rdb_backup_frequency          = 60
  rdb_backup_max_snapshot_count = 1
  redis_version                 = "6"
}

# apim
apim_publisher_name = "IO"
apim_v2_sku         = "Premium_2"
apim_autoscale = {
  enabled                       = true
  default_instances             = 5
  minimum_instances             = 4
  maximum_instances             = 6
  scale_out_capacity_percentage = 50
  scale_out_time_window         = "PT3M"
  scale_out_value               = "1"
  scale_out_cooldown            = "PT5M"
  scale_in_capacity_percentage  = 20
  scale_in_time_window          = "PT5M"
  scale_in_value                = "1"
  scale_in_cooldown             = "PT5M"
}

# azure devops
azdo_sp_tls_cert_enabled = true
enable_azdoa             = true
enable_iac_pipeline      = true
azdoa_image_name         = "azdo-agent-ubuntu2204-image-v2"
##

## Monitor
log_analytics_workspace_name                = "io-p-law-common"
application_insights_name                   = "io-p-ai-common"
monitor_resource_group_name                 = "io-p-rg-common"
log_analytics_workspace_resource_group_name = "io-p-rg-common"
##

## Event hub
ehns_sku_name                 = "Standard"
ehns_capacity                 = 5
ehns_auto_inflate_enabled     = true
ehns_maximum_throughput_units = 5
ehns_zone_redundant           = true
ehns_alerts_enabled           = true

ehns_ip_rules = [
  {
    ip_mask = "18.192.147.151", # PDND
    action  = "Allow"
  },
  {
    ip_mask = "18.159.227.69", # PDND
    action  = "Allow"
  },
  {
    ip_mask = "3.126.198.129", # PDND
    action  = "Allow"
  }
]

ehns_metric_alerts = {
  no_trx = {
    aggregation = "Total"
    metric_name = "IncomingMessages"
    description = "No transactions received from acquirer in the last 24h"
    operator    = "LessThanOrEqual"
    threshold   = 1000
    frequency   = "PT1H"
    window_size = "P1D"
    dimension = [
      {
        name     = "EntityName"
        operator = "Include"
        values   = ["rtd-trx"]
      }
    ],
  },
  active_connections = {
    aggregation = "Average"
    metric_name = "ActiveConnections"
    description = null
    operator    = "LessThanOrEqual"
    threshold   = 0
    frequency   = "PT5M"
    window_size = "PT15M"
    dimension   = [],
  },
  error_trx = {
    aggregation = "Total"
    metric_name = "IncomingMessages"
    description = "Transactions rejected from one acquirer file received. trx write on eventhub. check immediately"
    operator    = "GreaterThan"
    threshold   = 0
    frequency   = "PT5M"
    window_size = "PT30M"
    dimension = [
      {
        name     = "EntityName"
        operator = "Include"
        values = ["bpd-trx-error",
        "rtd-trx-error"]
      }
    ],
  },
}

# Functions App
function_app_kind              = "Linux"
function_app_sku_tier          = "PremiumV3"
function_app_sku_size          = "P1v3"
function_app_autoscale_minimum = 2
function_app_autoscale_maximum = 30
function_app_autoscale_default = 10

# Functions Services
function_services_kind              = "Linux"
function_services_sku_tier          = "PremiumV3"
function_services_sku_size          = "P1v3"
function_services_autoscale_minimum = 1
function_services_autoscale_maximum = 30
function_services_autoscale_default = 10

# Functions App Async
function_app_async_kind              = "Linux"
function_app_async_sku_tier          = "PremiumV3"
function_app_async_sku_size          = "P1v3"
function_app_async_autoscale_minimum = 3 # 2 instance to achieve redundancy and failover
function_app_async_autoscale_maximum = 30
function_app_async_autoscale_default = 10

# Functions Admin
function_admin_kind              = "Linux"
function_admin_sku_tier          = "PremiumV3"
function_admin_sku_size          = "P1v3"
function_admin_autoscale_minimum = 1
function_admin_autoscale_maximum = 3
function_admin_autoscale_default = 1

# Functions shared
plan_shared_1_kind                = "Linux"
plan_shared_1_sku_tier            = "PremiumV3"
plan_shared_1_sku_size            = "P1v3"
function_public_autoscale_minimum = 1
function_public_autoscale_maximum = 30
function_public_autoscale_default = 10

app_backend_autoscale_default = 10
app_backend_autoscale_minimum = 2
app_backend_autoscale_maximum = 30

# Function CDN Assets
function_assets_cdn_kind              = "Linux"
function_assets_cdn_sku_tier          = "PremiumV3"
function_assets_cdn_sku_size          = "P1v3"
function_assets_cdn_autoscale_minimum = 1
function_assets_cdn_autoscale_maximum = 5
function_assets_cdn_autoscale_default = 1

# App Continua DynamicLynk

eventhubs = [
  {
    name              = "io-cosmosdb-services"
    partitions        = 5
    message_retention = 7
    consumers         = []
    keys = [
      {
        name   = "io-fn-elt"
        listen = false
        send   = true
        manage = false
      },
      {
        name   = "pdnd"
        listen = true
        send   = false
        manage = false
      }
    ]
  },
  {
    name              = "io-cosmosdb-profiles"
    partitions        = 5
    message_retention = 7
    consumers         = []
    keys = [
      {
        name   = "io-fn-elt"
        listen = false
        send   = true
        manage = false
      },
      {
        name   = "pdnd"
        listen = true
        send   = false
        manage = false
      }
    ]
  },
  {
    name              = "import-command"
    partitions        = 2
    message_retention = 7
    consumers         = []
    keys = [
      {
        name   = "ops"
        listen = false
        send   = true
        manage = false
      },
      {
        name   = "io-fn-elt"
        listen = true
        send   = false
        manage = false
      }
    ]
  },
  {
    name              = "io-cosmosdb-message-status"
    partitions        = 32
    message_retention = 7
    consumers         = ["io-messages"]
    keys = [
      {
        name   = "io-cdc"
        listen = false
        send   = true
        manage = false
      },
      {
        name   = "io-messages"
        listen = true
        send   = false
        manage = false
      }
    ]
  },
  {
    name              = "pdnd-io-cosmosdb-messages"
    partitions        = 30
    message_retention = 7
    consumers         = []
    keys = [
      {
        name   = "io-fn-elt"
        listen = false
        send   = true
        manage = false
      },
      {
        name   = "pdnd"
        listen = true
        send   = false
        manage = false
      }
    ]
  },
  {
    name              = "pdnd-io-cosmosdb-message-status"
    partitions        = 30
    message_retention = 7
    consumers         = []
    keys = [
      {
        name   = "io-fn-elt"
        listen = false
        send   = true
        manage = false
      },
      {
        name   = "pdnd"
        listen = true
        send   = false
        manage = false
      }
    ]
  },
  {
    name              = "pdnd-io-cosmosdb-service-preferences"
    partitions        = 30
    message_retention = 7
    consumers         = []
    keys = [
      {
        name   = "io-fn-elt"
        listen = false
        send   = true
        manage = false
      },
      {
        name   = "pdnd"
        listen = true
        send   = false
        manage = false
      }
    ]
  },
  {
    name              = "pdnd-io-cosmosdb-profiles"
    partitions        = 30
    message_retention = 7
    consumers         = []
    keys = [
      {
        name   = "io-fn-elt"
        listen = false
        send   = true
        manage = false
      },
      {
        name   = "pdnd"
        listen = true
        send   = false
        manage = false
      }
    ]
  },
  {
    name              = "pdnd-io-cosmosdb-notification-status"
    partitions        = 30
    message_retention = 7
    consumers         = []
    keys = [
      {
        name   = "io-fn-elt"
        listen = false
        send   = true
        manage = false
      },
      {
        name   = "pdnd"
        listen = true
        send   = false
        manage = false
      }
    ]
  },
  {
    name              = "io-cosmosdb-message-status-for-view"
    partitions        = 32
    message_retention = 7
    consumers         = ["io-messages"]
    keys = [
      {
        name   = "io-cdc"
        listen = false
        send   = true
        manage = false
      },
      {
        name   = "io-messages"
        listen = true
        send   = false
        manage = false
      }
    ]
  }
]

# PN Service Id
pn_service_id = "01G40DWQGKY5GRWSNM4303VNRP"

# PN Test Endpoint
pn_test_endpoint = "https://api-io.uat.notifichedigitali.it"

# RECEIPT SERVICE
io_receipt_service_id       = "01HD63674XJ1R6XCNHH24PCRR2"
io_receipt_service_url      = "https://api.platform.pagopa.it/receipts/service/v1"
io_receipt_service_test_id  = "01H4ZJ62C1CPGJ0PX8Q1BP7FAB"
io_receipt_service_test_url = "https://api.uat.platform.pagopa.it/receipts/service/v1"

# TP Mock Service Id
third_party_mock_service_id = "01GQQDPM127KFGG6T3660D5TXD"

app_backend_names = ["appbackendl1", "appbackendl2", "appbackendli"]
