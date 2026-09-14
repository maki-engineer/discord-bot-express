terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # bootstrap は「State バケットそのもの」を作るため、State をローカルに置く。
  # ここで作ったバケットを、ルート構成（infra/）のリモート State として使う。
}
