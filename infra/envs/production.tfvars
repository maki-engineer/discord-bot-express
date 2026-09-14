# 本番環境の設定値。
# 秘密情報はここに書かない（Secret Manager に登録し、シークレットIDだけを指定する）。

project_id = "discord-bot-507515"
region     = "asia-northeast1"

########################################
# Artifact Registry
########################################

# 既存のリポジトリ名に合わせる。確認コマンド:
#   gcloud artifacts repositories list --project=discord-bot-507515 --location=asia-northeast1
artifact_registry_repository_id = "backend"
backend_image_name              = "backend"

# 削除対象を目視確認してから false にする
artifact_registry_cleanup_dry_run = true

########################################
# Cloud Run
########################################

cloud_run_service_name = "discord-bot-backend"

cloud_run_cpu                = "1"
cloud_run_memory             = "512Mi"
cloud_run_min_instance_count = 0
cloud_run_max_instance_count = 3

# /api/members はメンバーの氏名と誕生日を返すため、公開してよいか判断してから変更する。
# 現状の設定は次のコマンドで確認できる:
#   gcloud run services get-iam-policy discord-bot-backend \
#     --region=asia-northeast1 --project=discord-bot-507515
cloud_run_allow_unauthenticated = false

########################################
# Secret Manager
########################################

backend_secret_env_vars = {
  POSTGRES_URL = "backend-postgres-url"
}

########################################
# GitHub Actions
########################################

github_repository  = "maki-engineer/discord-bot"
github_allowed_ref = "refs/heads/main"
