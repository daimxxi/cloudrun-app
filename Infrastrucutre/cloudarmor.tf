# Cloud Armor Security Policy
resource "google_compute_security_policy" "cloud_armor" {
  name   = "${var.cloudrun_service_name}-security-policy"

  rule {
    action   = "allow"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["0.0.0.0/0"]
      }
    }
  }
}