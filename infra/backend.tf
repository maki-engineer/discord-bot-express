terraform {
  # バケット名はプロジェクトごとに変わり、backend ブロックでは変数が使えないため、
  # 部分設定にして terraform init で渡す。
  #
  #   terraform init -backend-config=envs/production.gcs.tfbackend
  #
  # バケットは infra/bootstrap で先に作成しておく。
  backend "gcs" {}
}
