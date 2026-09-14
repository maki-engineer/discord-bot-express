locals {
  # 環境変数名 => シークレットID の map から、シークレットID の集合を作る
  backend_secret_ids = toset(values(var.backend_secret_env_vars))
}

# シークレットの「入れ物」だけを管理する。
# google_secret_manager_secret_version は意図的に作成しない。
# State に値が残るのを避けるため、値の登録は gcloud で行う。
resource "google_secret_manager_secret" "backend" {
  for_each = local.backend_secret_ids

  project   = var.project_id
  secret_id = each.value

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

# Cloud Run の実行用サービスアカウントにだけ読み取りを許可する
resource "google_secret_manager_secret_iam_member" "cloud_run_runtime_accessor" {
  for_each = google_secret_manager_secret.backend

  project   = var.project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_runtime.email}"
}
