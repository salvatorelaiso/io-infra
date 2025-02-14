resource "azurerm_web_application_firewall_policy" "api_app" {
  name                = try(local.nonstandard[var.location_short].waf_api_app, "${var.project}-waf-agw-api-app-01")
  resource_group_name = var.resource_groups.external
  location            = var.location

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {

    managed_rule_set {
      type    = "OWASP"
      version = "3.1"

      rule_group_override {
        rule_group_name = "REQUEST-913-SCANNER-DETECTION"
        disabled_rules = [
          "913100",
          "913101",
          "913102",
          "913110",
          "913120",
        ]
      }

      rule_group_override {
        rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"
        disabled_rules = [
          "920300",
          "920320",
        ]
      }

      rule_group_override {
        rule_group_name = "REQUEST-930-APPLICATION-ATTACK-LFI"
        disabled_rules = [
          "930120",
        ]
      }

      rule_group_override {
        rule_group_name = "REQUEST-932-APPLICATION-ATTACK-RCE"
        disabled_rules = [
          "932150",
        ]
      }

      rule_group_override {
        rule_group_name = "REQUEST-941-APPLICATION-ATTACK-XSS"
        disabled_rules = [
          "941130",
        ]
      }

      rule_group_override {
        rule_group_name = "REQUEST-942-APPLICATION-ATTACK-SQLI"
        disabled_rules = [
          "942100",
          "942120",
          "942190",
          "942200",
          "942210",
          "942240",
          "942250",
          "942260",
          "942330",
          "942340",
          "942370",
          "942380",
          "942430",
          "942440",
          "942450",
        ]
      }

    }
  }

  tags = var.tags
}