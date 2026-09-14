resource "google_project_service" "storage" {
  project = var.project_id
  service = "storage.googleapis.com"

  disable_on_destroy = false
}

# Terraform の State を保存するバケット。
# State には接続文字列などの機密情報が含まれる可能性があるため、
# 公開アクセスを禁止し、バージョニングを有効にする。
resource "google_storage_bucket" "terraform_state" {
  project  = var.project_id
  name     = var.state_bucket_name
  location = var.state_bucket_location

  # State バケットは誤って消さないよう、中身があるうちは削除できないようにする
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  # 古い世代が無限に増えないようにする
  lifecycle_rule {
    condition {
      num_newer_versions = var.state_bucket_keep_versions
    }

    action {
      type = "Delete"
    }
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.storage]
}
