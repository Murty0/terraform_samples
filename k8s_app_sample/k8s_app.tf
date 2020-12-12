resource "kubernetes_config_map" "app_config" {
  provider = kubernetes.templates
  metadata {
    name = "app-config-${var.branch}"
    labels = {
      app = "app-${var.branch}"
    }
  }

  data = {
    "config.yaml" = <<-EOT
  region: "${var.region}"
  branch: "${var.branch}"
  home_path: /home/app
  EOT
  }
}

resource "kubernetes_service" "app_svc" {
  provider = kubernetes.templates
  metadata {
    name = "app-svc-${var.branch}"
    labels = {
      app = "app-${var.branch}"
    }
  }

  spec {
    port {
      port = 8080
      name = "app"
    }

    selector = {
      app = "app-${var.branch}"
    }

  }
}

resource "kubernetes_deployment" "app_dpt" {
  provider = kubernetes.templates
  metadata {
    annotations = {}
    name        = "app-${var.branch}"
    labels      = {}
  }

  spec {
    selector {
      match_labels = {
        app = "app-${var.branch}" # has to match .spec.template.metadata.labels
      }
    }

    replicas = var.app_replicas

    template {
      metadata {
        labels = {
          app = "app-${var.branch}" # has to match .spec.selector.match_labels
        }
      }

      spec {
        termination_grace_period_seconds = var.app_termination_grace_period_seconds
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "node_purpose"
                  operator = "In"
                  values   = ["compute"]
                }
              }
            }
          }
        }
        container {
          name = "app-ctr"
          lifecycle {
            pre_stop {
              exec {
                command = ["bash", "-c", "pkill --signal SIGTERM python && sleep 3"]
              }
            }
          }

          resources {
            limits {
              cpu    = var.app_limits_cpu
              memory = var.app_limits_memory
            }
            requests {
              cpu    = var.app_requests_cpu
              memory = var.app_requests_memory
            }
          }

          image_pull_policy = "Always"
          image             = "0123456789.dkr.ecr.${var.region}.amazonaws.com/app-${var.branch}:${var.app_branch_image_tag}"
          port {
            container_port = 8080
            name           = "app"
          }

          env {
            name = "DD_AGENT_HOST"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          env {
            name  = "DD_DOGSTATSD_PORT"
            value = "8125"
          }

          env {
            name = "DOGSTATSD_HOST_IP"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          readiness_probe {
            http_get {
              path = "/ping"
              port = 8080
            }

            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 1
          }

          liveness_probe {

            exec {
              command = ["bash", "/home/app/liveness.sh"]
            }
            initial_delay_seconds = 60
            period_seconds        = 5
            timeout_seconds       = 2
            failure_threshold     = 2
          }

          volume_mount {
            mount_path = "/home/app/etc/config.yaml"
            sub_path   = "config.yaml"
            name       = "config"
            read_only  = true
          }


          volume_mount {
            mount_path = "/home/app/.aws/credentials"
            sub_path   = "${var.branch}-app-aws-auth-k8s"
            name       = "${var.branch}-aws-key"
            read_only  = true
          }

          volume_mount {
            mount_path = "/var/run/datadog"
            name       = "dsdsocket"
            read_only  = true
          }
        }

        volume {
          name = "config"
          config_map {
            name = "app-config-${var.branch}"
          }
        }

        volume {
          name = "${var.branch}-aws-key"
          secret {
            secret_name = "${var.branch}-app-aws-auth-k8s"
          }
        }

        volume {
          name = "dsdsocket"
          host_path {
            path = "/var/run/datadog"
          }
        }
      }
    }
  }
}
