resource "google_cloud_run_v2_service" "backend" {
  project     = var.project_id
  name        = var.cloud_run_service_name
  location    = var.region
  description = "Discord Bot の Backend API"

  ingress             = var.cloud_run_ingress
  deletion_protection = var.cloud_run_deletion_protection

  template {
    service_account = google_service_account.cloud_run_runtime.email
    timeout         = "${var.cloud_run_request_timeout_seconds}s"

    scaling {
      min_instance_count = var.cloud_run_min_instance_count
      max_instance_count = var.cloud_run_max_instance_count
    }

    containers {
      image = local.backend_image

      ports {
        container_port = var.container_port
      }

      resources {
        limits = {
          cpu    = var.cloud_run_cpu
          memory = var.cloud_run_memory
        }

        cpu_idle          = var.cloud_run_cpu_idle
        startup_cpu_boost = true
      }

      env {
        name  = "APP_ENV"
        value = var.app_env
      }

      env {
        name  = "TZ"
        value = var.timezone
      }

      # 秘密情報は値を直接渡さず、Secret Manager から参照する
      dynamic "env" {
        for_each = var.backend_secret_env_vars

        content {
          name = env.key

          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.backend[env.value].secret_id
              version = "latest"
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      # コンテナイメージの更新はアプリケーションのデプロイ（GitHub Actions）が担当する。
      # Terraform が古いイメージに巻き戻さないよう、差分を無視する。
      template[0].containers[0].image,

      # gcloud や GitHub Actions のデプロイがこれらを書き換えるため、
      # 無視しないと毎回 plan に差分が出続ける。
      client,
      client_version,
    ]
  }

  depends_on = [
    google_project_service.required,
    google_secret_manager_secret_iam_member.cloud_run_runtime_accessor,
  ]
}

# 認証なしの公開アクセス。
# cloud_run_allow_unauthenticated を true にしたときだけ作成する。
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count = var.cloud_run_allow_unauthenticated ? 1 : 0

  project  = var.project_id
  location = google_cloud_run_v2_service.backend.location
  name     = google_cloud_run_v2_service.backend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
