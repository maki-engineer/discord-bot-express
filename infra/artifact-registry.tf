resource "google_artifact_registry_repository" "backend" {
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_repository_id
  description   = "Backend の Docker イメージを保存するリポジトリ"
  format        = "DOCKER"

  docker_config {
    # 同じ :latest タグを繰り返し push するため、タグの上書きを許可する
    immutable_tags = false
  }

  cleanup_policy_dry_run = var.artifact_registry_cleanup_dry_run

  # タグ付きイメージは新しいものから一定数を残す
  cleanup_policies {
    id     = "keep-recent-tagged-images"
    action = "KEEP"

    most_recent_versions {
      keep_count = var.artifact_registry_keep_count
    }
  }

  # :latest を上書きしてタグが外れた古いイメージを削除する
  cleanup_policies {
    id     = "delete-old-untagged-images"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = var.artifact_registry_untagged_retention
    }
  }

  depends_on = [google_project_service.required]
}
