# GitHub Actions から Google Cloud を操作するための Workload Identity Federation。
# サービスアカウントキー（JSON）を発行・保管しないための仕組み。

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.workload_identity_pool_id
  display_name              = "GitHub Actions"
  description               = "GitHub Actions からのデプロイに使う Workload Identity Pool"

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.workload_identity_pool_provider_id
  display_name                       = "GitHub"
  description                        = "GitHub Actions の OIDC トークンを受け付ける"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # 指定したリポジトリ（と ref）から発行されたトークンだけを受け付ける。
  # これを付けないと、他のリポジトリからでも認証できてしまう。
  attribute_condition = local.github_attribute_condition

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# 指定リポジトリのワークフローが、デプロイ用サービスアカウントを借用できるようにする
resource "google_service_account_iam_member" "github_workload_identity_user" {
  service_account_id = google_service_account.github_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}
