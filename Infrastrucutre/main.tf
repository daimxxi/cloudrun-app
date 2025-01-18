# CloudRun Service
resource "google_cloud_run_v2_service" "default" {
  provider = google-beta
  name     = var.cloudrun_service_name
  location = var.region
  deletion_protection = true
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  default_uri_disabled = true

  template {
    containers {
        name  = "main"
        image = "eu.gcr.io/${var.project_id}/what-time-is-it:<TAG>"
        ports {
            container_port = 8080
        }
    resources {
        limits = {
            cpu    = "2"
            memory = "1024Mi"
        }
        startup_cpu_boost = true
    }
     startup_probe {
        initial_delay_seconds = 30
        timeout_seconds = 150
        period_seconds = 10
        failure_threshold = 3
        tcp_socket {
          port = 8080
        }
      }
      liveness_probe {
        initial_delay_seconds = 30
        timeout_seconds = 150
        period_seconds = 10
        failure_threshold = 3
        http_get {
          path = "/"
        }
    }
    }
    scaling {
      min_instance_count = 2
      max_instance_count = 4
    }
  }

  traffic {
    percent         = 100
  }
}

################## Exposing CloudRun behind GCP Load Balancer ######################

# Application Load Balancer
resource "google_compute_global_address" "cloudrun_lb_ip" {
  name = "${var.cloudrun_service_name}-lb-ip"
  address_type = "EXTERNAL"
}

resource "google_compute_managed_ssl_certificate" "managed_cert" {
  name   = "${var.cloudrun_service_name}-managed-cert"
  description = "Certificate for cloud run service domain"
  managed {
    domains = ["domain.example.com"]
  }
  lifecycle {
    create_before_destroy = true
  }
}

# Backend Service for CloudRun
resource "google_compute_region_network_endpoint_group" "cloudrun_neg" {
  name                  = "${var.cloudrun_service_name}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = google_cloud_run_v2_service.default.name
  }
}

resource "google_compute_backend_service" "cloudrun_backend" {
  name           = "${var.cloudrun_service_name}-backend"
  timeout_sec    = 30
  connection_draining_timeout_sec = 60

  backend {
    group = google_compute_region_network_endpoint_group.cloudrun_neg.id
  }

  security_policy = google_compute_security_policy.cloud_armor.id
}

resource "google_compute_url_map" "url_map" {
  name            = "${var.cloudrun_service_name}-url-map"
  default_service = google_compute_backend_service.cloudrun_backend.id
}

resource "google_compute_target_https_proxy" "https_proxy" {
  name        = "${var.cloudrun_service_name}-https-proxy"
  ssl_certificates = [google_compute_managed_ssl_certificate.managed_cert.id]
  url_map     = google_compute_url_map.url_map.id
}

resource "google_compute_forwarding_rule" "https_forwarding_rule" {
  name        = "${var.cloudrun_service_name}-https-forwarding-rule"
  target      = google_compute_target_https_proxy.https_proxy.id
  port_range  = "443"
  ip_protocol = "TCP"
  ip_address  = google_compute_global_address.cloudrun_lb_ip.address
}

# Redirect HTTP traffic to HTTPS
resource "google_compute_url_map" "https_redirect" {
  name            = "${var.cloudrun_service_name}-https-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "https_redirect" {
  name   = "${var.cloudrun_service_name}-http-proxy"
  url_map          = google_compute_url_map.https_redirect.id
}

resource "google_compute_global_forwarding_rule" "https_redirect" {
  name   = "${var.cloudrun_service_name}-lb-http"

  target = google_compute_target_http_proxy.https_redirect.id
  port_range = "80"
  ip_address = google_compute_global_address.cloudrun_lb_ip.address
}
