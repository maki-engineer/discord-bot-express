locals {
  # 例: asia-northeast1-docker.pkg.dev
  artifact_registry_host = "${var.region}-docker.pkg.dev"

  # 例: asia-northeast1-docker.pkg.dev/discord-bot-507515/backend
  artifact_registry_path = join("/", [
    local.artifact_registry_host,
    var.project_id,
    var.artifact_registry_repository_id,
  ])

  backend_image = "${local.artifact_registry_path}/${var.backend_image_name}:${var.backend_image_tag}"

  # GitHub Actions から受け付けるトークンの条件。
  # リポジトリを限定し、github_allowed_ref が指定されていれば ref も限定する。
  # 空文字は compact で除去される。
  github_repository_condition = "assertion.repository == \"${var.github_repository}\""

  github_ref_condition = var.github_allowed_ref == null ? "" : "assertion.ref == \"${var.github_allowed_ref}\""

  github_attribute_condition = join(" && ", compact([
    local.github_repository_condition,
    local.github_ref_condition,
  ]))
}
