########################################
# Cloud Run の実行用サービスアカウント
########################################

# Cloud Run はこのサービスアカウントとして動く。
# 既定のコンピュートサービスアカウントより権限を絞るために専用のものを用意する。
resource "google_service_account" "cloud_run_runtime" {
  project      = var.project_id
  account_id   = var.cloud_run_runtime_service_account_id
  display_name = "Discord Bot Backend (Cloud Run runtime)"
  description  = "Cloud Run サービス ${var.cloud_run_service_name} の実行用"

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "cloud_run_runtime" {
  for_each = toset(var.cloud_run_runtime_project_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_run_runtime.email}"
}

########################################
# GitHub Actions からのデプロイ用サービスアカウント
########################################

resource "google_service_account" "github_deployer" {
  project      = var.project_id
  account_id   = var.github_deployer_service_account_id
  display_name = "GitHub Actions Deployer"
  description  = "GitHub Actions から Cloud Run にデプロイするための権限"

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "github_deployer" {
  for_each = toset(var.github_deployer_project_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_deployer.email}"
}

# Cloud Run のデプロイ時に「実行用サービスアカウントとして動かす」ために必要。
# プロジェクト全体ではなく、対象のサービスアカウントに限定して付与する。
resource "google_service_account_iam_member" "github_deployer_act_as_runtime" {
  service_account_id = google_service_account.cloud_run_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_deployer.email}"
}
