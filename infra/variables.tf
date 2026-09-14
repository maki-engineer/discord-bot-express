########################################
# プロジェクト共通
########################################

variable "project_id" {
  description = "Google Cloud のプロジェクトID"
  type        = string
}

variable "region" {
  description = "Cloud Run と Artifact Registry のリージョン"
  type        = string
  default     = "asia-northeast1"
}

########################################
# Artifact Registry
########################################

variable "artifact_registry_repository_id" {
  description = <<-EOT
    Backend のイメージを置く Artifact Registry リポジトリのID。
    既存のリポジトリ名は次のコマンドで確認できる。
      gcloud artifacts repositories list --project=<PROJECT_ID> --location=<REGION>
  EOT
  type        = string
  default     = "backend"
}

variable "backend_image_name" {
  description = "Backend のイメージ名（Artifact Registry リポジトリ内のパス）"
  type        = string
  default     = "backend"
}

variable "backend_image_tag" {
  description = <<-EOT
    Cloud Run を新規作成するときの初期タグ。
    作成後のイメージ更新は GitHub Actions 側のデプロイが担当し、
    Terraform では差分を無視する（cloud-run.tf の lifecycle を参照）。
  EOT
  type        = string
  default     = "latest"
}

variable "artifact_registry_cleanup_dry_run" {
  description = <<-EOT
    クリーンアップポリシーをドライランにするかどうか。
    初回は true のままにして、Artifact Registry の画面で削除対象を確認してから false にする。
  EOT
  type        = bool
  default     = true
}

variable "artifact_registry_keep_count" {
  description = "タグ付きイメージを新しいものから何世代残すか"
  type        = number
  default     = 10
}

variable "artifact_registry_untagged_retention" {
  description = "タグが外れたイメージを削除するまでの期間（秒数の文字列）"
  type        = string
  default     = "2592000s" # 30日
}

########################################
# Cloud Run
########################################

variable "cloud_run_service_name" {
  description = "Cloud Run のサービス名"
  type        = string
  default     = "discord-bot-backend"
}

variable "container_port" {
  description = <<-EOT
    コンテナがリクエストを受けるポート。
    backend/src/cmd/main.go が :8080 を直接指定しているため 8080 固定にしている。
  EOT
  type        = number
  default     = 8080
}

variable "app_env" {
  description = "Backend に渡す APP_ENV。backend/src/config/config.go が解釈する値を指定する。"
  type        = string
  default     = "production"
}

variable "timezone" {
  description = "コンテナのタイムゾーン"
  type        = string
  default     = "Asia/Tokyo"
}

variable "cloud_run_cpu" {
  description = "1インスタンスあたりのCPU"
  type        = string
  default     = "1"
}

variable "cloud_run_memory" {
  description = "1インスタンスあたりのメモリ"
  type        = string
  default     = "512Mi"
}

variable "cloud_run_cpu_idle" {
  description = <<-EOT
    リクエストが無いときにCPUを割り当てないかどうか（true でリクエスト課金のみ）。
    常時CPUが必要な処理は無いため既定は true。
  EOT
  type        = bool
  default     = true
}

variable "cloud_run_min_instance_count" {
  description = "最小インスタンス数。0 だとコールドスタートが発生する。"
  type        = number
  default     = 0
}

variable "cloud_run_max_instance_count" {
  description = "最大インスタンス数"
  type        = number
  default     = 3
}

variable "cloud_run_request_timeout_seconds" {
  description = "リクエストのタイムアウト秒数"
  type        = number
  default     = 60
}

variable "cloud_run_ingress" {
  description = <<-EOT
    受け付けるトラフィックの範囲。
      INGRESS_TRAFFIC_ALL                        すべて
      INGRESS_TRAFFIC_INTERNAL_ONLY              VPC内部のみ
      INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER     内部ロードバランサ経由のみ
  EOT
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"

  validation {
    condition = contains([
      "INGRESS_TRAFFIC_ALL",
      "INGRESS_TRAFFIC_INTERNAL_ONLY",
      "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER",
    ], var.cloud_run_ingress)
    error_message = "cloud_run_ingress に指定できない値です。"
  }
}

variable "cloud_run_allow_unauthenticated" {
  description = <<-EOT
    認証なしの呼び出し（allUsers への roles/run.invoker）を許可するかどうか。

    Backend の /api/members はメンバーの氏名と誕生日を返すため、
    公開してよいかを判断してから true にする。
    現状の設定は次のコマンドで確認できる。
      gcloud run services get-iam-policy <SERVICE_NAME> --region=<REGION> --project=<PROJECT_ID>
  EOT
  type        = bool
  default     = false
}

variable "cloud_run_deletion_protection" {
  description = "Cloud Run サービスの削除保護。誤って destroy しないよう既定は true。"
  type        = bool
  default     = true
}

########################################
# Secret Manager
########################################

variable "backend_secret_env_vars" {
  description = <<-EOT
    Cloud Run に環境変数として渡す秘密情報。
    キーが環境変数名、値が Secret Manager のシークレットID。

    シークレットの「入れ物」だけ Terraform で作成し、中身（バージョン）は登録しない。
    値の登録は次のように手動で行う。
      printf '%s' "<VALUE>" | gcloud secrets versions add <SECRET_ID> --data-file=- --project=<PROJECT_ID>
  EOT
  type        = map(string)
  default = {
    POSTGRES_URL = "backend-postgres-url"
  }
}

########################################
# サービスアカウント
########################################

variable "cloud_run_runtime_service_account_id" {
  description = "Cloud Run の実行用サービスアカウントのID（@より前の部分）"
  type        = string
  default     = "discord-bot-backend-run"
}

variable "github_deployer_service_account_id" {
  description = "GitHub Actions からのデプロイに使うサービスアカウントのID（@より前の部分）"
  type        = string
  default     = "github-actions-deployer"
}

variable "cloud_run_runtime_project_roles" {
  description = "Cloud Run 実行用サービスアカウントに付与するプロジェクトレベルのロール"
  type        = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/cloudtrace.agent",
  ]
}

variable "github_deployer_project_roles" {
  description = <<-EOT
    デプロイ用サービスアカウントに付与するプロジェクトレベルのロール。

    Cloud Build を使わず GitHub Actions 内で docker build して
    Artifact Registry に push する場合は、roles/cloudbuild.builds.editor を外せる。
  EOT
  type        = list(string)
  default = [
    "roles/run.developer",
    "roles/artifactregistry.writer",
    "roles/cloudbuild.builds.editor",
  ]
}

########################################
# Workload Identity Federation（GitHub Actions）
########################################

variable "github_repository" {
  description = "デプロイを許可する GitHub リポジトリ（owner/repo）"
  type        = string
  default     = "maki-engineer/discord-bot"
}

variable "github_allowed_ref" {
  description = <<-EOT
    デプロイを許可する Git ref。null にすると ref による制限を行わない。
    例: refs/heads/main
  EOT
  type        = string
  default     = "refs/heads/main"
}

variable "workload_identity_pool_id" {
  description = "Workload Identity Pool のID"
  type        = string
  default     = "github-actions"
}

variable "workload_identity_pool_provider_id" {
  description = "Workload Identity Pool Provider のID"
  type        = string
  default     = "github"
}
