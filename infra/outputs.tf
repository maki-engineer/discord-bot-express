output "cloud_run_service_name" {
  description = "Cloud Run のサービス名"
  value       = google_cloud_run_v2_service.backend.name
}

output "cloud_run_service_url" {
  description = "Cloud Run サービスのURL"
  value       = google_cloud_run_v2_service.backend.uri
}

output "artifact_registry_path" {
  description = "docker push 先のリポジトリパス"
  value       = local.artifact_registry_path
}

output "backend_image" {
  description = "Backend のイメージURL（タグ込み）"
  value       = local.backend_image
}

output "cloud_run_runtime_service_account_email" {
  description = "Cloud Run の実行用サービスアカウント"
  value       = google_service_account.cloud_run_runtime.email
}

output "github_deployer_service_account_email" {
  description = "GitHub Actions のデプロイ用サービスアカウント。ワークフローの service_account に指定する。"
  value       = google_service_account.github_deployer.email
}

output "workload_identity_provider" {
  description = <<-EOT
    google-github-actions/auth の workload_identity_provider に指定する値。
  EOT
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "backend_secret_ids" {
  description = "作成した Secret Manager のシークレットID（値は別途 gcloud で登録する）"
  value       = [for secret in google_secret_manager_secret.backend : secret.secret_id]
}
