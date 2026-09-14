output "state_bucket_name" {
  description = "作成した State バケット名。ルート構成の terraform init で -backend-config に渡す。"
  value       = google_storage_bucket.terraform_state.name
}

output "backend_config_hint" {
  description = "ルート構成（infra/）で実行する terraform init コマンド"
  value       = "terraform init -backend-config=\"bucket=${google_storage_bucket.terraform_state.name}\" -backend-config=\"prefix=backend/production\""
}
