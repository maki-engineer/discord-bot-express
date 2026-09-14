variable "project_id" {
  description = "Google Cloud のプロジェクトID"
  type        = string
}

variable "region" {
  description = "既定のリージョン"
  type        = string
  default     = "asia-northeast1"
}

variable "state_bucket_name" {
  description = <<-EOT
    Terraform の State を保存する GCS バケット名。
    バケット名は Google Cloud 全体で一意である必要があるため、プロジェクトIDを含めた名前にする。
  EOT
  type        = string
}

variable "state_bucket_location" {
  description = "State バケットのロケーション"
  type        = string
  default     = "ASIA-NORTHEAST1"
}

variable "state_bucket_keep_versions" {
  description = "State バケットで保持する世代数（これより古い世代は削除される）"
  type        = number
  default     = 10
}
