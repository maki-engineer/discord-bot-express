# Infrastructure

Backend のデプロイ先である Google Cloud のインフラストラクチャを、Terraform でコード管理するためのフォルダです。

Cloud Run を中心に、Artifact Registry、Secret Manager、サービスアカウント、GitHub Actions 用の Workload Identity Federation を管理します。データベースは Google Cloud 外のマネージド PostgreSQL（Neon）を利用しているため、Cloud SQL は管理対象に含めていません。

## 管理対象

| リソース | ファイル |
| --- | --- |
| 有効化する API | `apis.tf` |
| Artifact Registry の Docker リポジトリ | `artifact-registry.tf` |
| Cloud Run のサービスと公開設定 | `cloud-run.tf` |
| Secret Manager のシークレット（入れ物のみ） | `secret-manager.tf` |
| サービスアカウントと IAM | `iam.tf` |
| GitHub Actions 用の Workload Identity Federation | `github-oidc.tf` |
| Terraform の State を保存する GCS バケット | `bootstrap/` |

秘密情報は Terraform のコードや `.tfvars` に書きません。Secret Manager にはシークレットの**入れ物だけ**を Terraform で作り、値は `gcloud` で登録します。値を Terraform で管理すると State に平文で残るためです。

## ディレクトリ構成

```text
infra/
├── README.md
├── .gitignore
├── Taskfile.yml      # init / lint / plan / apply のショートカット
├── versions.tf       # Terraform と Provider のバージョン
├── backend.tf        # Remote State（GCS）の部分設定
├── providers.tf      # Google Provider
├── variables.tf      # 入力値
├── main.tf           # locals（イメージURLやOIDC条件の組み立て）
├── apis.tf           # 有効化する API
├── artifact-registry.tf
├── cloud-run.tf
├── secret-manager.tf
├── iam.tf            # サービスアカウントと IAM
├── github-oidc.tf    # Workload Identity Federation
├── outputs.tf        # 作成したリソースの出力
├── envs/
│   ├── production.tfvars           # 環境ごとの値（秘密情報は含めない）
│   └── production.gcs.tfbackend    # terraform init に渡す State の設定
└── bootstrap/        # State バケットを作るための別構成（State はローカル）
```

## 導入手順

すでに手作業で作成済みのリソースを Terraform の管理下に置く流れです。**いきなり `apply` すると既存リソースと衝突するため、必ず import を先に行ってください。**

### 1. 認証

```bash
gcloud auth application-default login
gcloud config set project discord-bot-507515
```

### 2. State バケットを作る（初回のみ）

State バケット自体を Terraform で作ると「State を置く場所が無い状態で State を作る」ことになるため、`bootstrap/` を別構成に分けてローカル State で実行します。

```bash
cd infra/bootstrap
cp terraform.tfvars.example terraform.tfvars   # 値を確認して必要なら修正
terraform init
terraform apply
```

`bootstrap/terraform.tfstate` はローカルに残ります。中身はバケット定義のみで秘密情報は含みませんが、`.gitignore` 対象です。

### 3. ルート構成を初期化

```bash
cd infra
terraform init -backend-config=envs/production.gcs.tfbackend
```

`envs/production.gcs.tfbackend` の `bucket` を、手順2で作成したバケット名に合わせてください。

### 4. 現状の値を調べて `envs/production.tfvars` を埋める

コードの既定値は推測を含みます。**import する前に実際の値を確認し、`envs/production.tfvars` を現状に合わせてください。** 値がずれていると、import 後の `plan` が不要な変更を出します。

```bash
PROJECT=discord-bot-507515
REGION=asia-northeast1

# Artifact Registry のリポジトリ名
gcloud artifacts repositories list --project=$PROJECT --location=$REGION

# リポジトリ内のイメージ名
gcloud artifacts docker images list \
  $REGION-docker.pkg.dev/$PROJECT/<REPOSITORY_ID> --include-tags

# Cloud Run の現在の設定（CPU、メモリ、スケーリング、実行SA、環境変数）
gcloud run services describe discord-bot-backend \
  --region=$REGION --project=$PROJECT --format=yaml

# 公開アクセスが許可されているか（allUsers に roles/run.invoker が付いているか）
gcloud run services get-iam-policy discord-bot-backend \
  --region=$REGION --project=$PROJECT

# 既存のサービスアカウント
gcloud iam service-accounts list --project=$PROJECT

# 既存のシークレット
gcloud secrets list --project=$PROJECT

# 既存の Workload Identity Pool
gcloud iam workload-identity-pools list --location=global --project=$PROJECT
```

### 5. 既存リソースを import

`terraform apply` で `409 ALREADY_EXISTS` になるリソースを import します。変数の既定値から名前を変えた場合は、コマンド内の ID も合わせて読み替えてください。

```bash
cd infra
export TF_CLI_ARGS_import="-var-file=envs/production.tfvars"

PROJECT=discord-bot-507515
REGION=asia-northeast1

# Artifact Registry
terraform import google_artifact_registry_repository.backend \
  "projects/$PROJECT/locations/$REGION/repositories/backend"

# Cloud Run
terraform import google_cloud_run_v2_service.backend \
  "projects/$PROJECT/locations/$REGION/services/discord-bot-backend"

# サービスアカウント（存在するものだけ）
terraform import google_service_account.cloud_run_runtime \
  "projects/$PROJECT/serviceAccounts/discord-bot-backend-run@$PROJECT.iam.gserviceaccount.com"

terraform import google_service_account.github_deployer \
  "projects/$PROJECT/serviceAccounts/github-actions-deployer@$PROJECT.iam.gserviceaccount.com"

# Secret Manager（キーは環境変数名ではなくシークレットID）
terraform import 'google_secret_manager_secret.backend["backend-postgres-url"]' \
  "projects/$PROJECT/secrets/backend-postgres-url"

# Workload Identity Federation
terraform import google_iam_workload_identity_pool.github \
  "projects/$PROJECT/locations/global/workloadIdentityPools/github-actions"

terraform import google_iam_workload_identity_pool_provider.github \
  "projects/$PROJECT/locations/global/workloadIdentityPools/github-actions/providers/github"
```

import しなくてよいもの:

- `google_project_service`（すでに有効なAPIをもう一度有効化してもエラーにならない）
- `google_project_iam_member` / `google_secret_manager_secret_iam_member` / `google_service_account_iam_member`（メンバー追加は冪等なので、既存の付与と衝突しない）

存在しないリソースは import せず、`apply` で新規作成されます。

> Workload Identity Pool を過去に作って削除したことがある場合、同じIDは30日間ソフトデリート状態で残り新規作成できません。`gcloud iam workload-identity-pools undelete` で復元してから import してください。

### 6. 差分を確認してから適用

```bash
terraform fmt -check -recursive
terraform validate
terraform plan -var-file=envs/production.tfvars
```

`Taskfile.yml` を使う場合は `task lint` と `task plan` でも同じことができます。

**`plan` の結果で次を必ず確認してください。**

- `destroy` や `replace`（`-/+`）が出ていないこと。出ている場合は import 漏れか、`envs/production.tfvars` の値が現状とずれています。
- Cloud Run の環境変数やスケーリング設定が意図しない値に変わっていないこと。

問題なければ適用します。

```bash
terraform apply -var-file=envs/production.tfvars
```

### 7. シークレットの値を登録

Terraform はシークレットの入れ物だけを作るため、値は手動で登録します。

```bash
printf '%s' 'postgresql://...' \
  | gcloud secrets versions add backend-postgres-url --data-file=- --project=discord-bot-507515
```

値を更新したいときも同じコマンドで新しいバージョンを追加します。Cloud Run は `latest` を参照しているため、次のリビジョンから新しい値が使われます。

## Terraform とアプリケーションデプロイの責務分担

同じ Cloud Run サービスを Terraform とデプロイ処理の両方が触るため、担当範囲を分けています。

| 担当 | 変更するもの |
| --- | --- |
| Terraform | サービスの構成（CPU、メモリ、スケーリング、環境変数、実行SA、公開設定、IAM） |
| デプロイ処理（GitHub Actions など） | コンテナイメージのタグのみ |

`cloud-run.tf` の `lifecycle.ignore_changes` で次の3つを無視しています。

- `template[0].containers[0].image` — Terraform が古いイメージに巻き戻さないようにするため
- `client` / `client_version` — `gcloud run deploy` がこれらを書き換えるため、無視しないと毎回 `plan` に差分が出続ける

そのため `terraform apply` を実行しても、動いているイメージは巻き戻りません。

## GitHub Actions からデプロイするときの設定値

`terraform apply` 後に次のコマンドで値を取得できます。

```bash
terraform output workload_identity_provider
terraform output github_deployer_service_account_email
terraform output artifact_registry_path
```

`google-github-actions/auth` にはこの2つを渡します。サービスアカウントキー（JSON）の発行は不要です。

```yaml
permissions:
  contents: read
  id-token: write   # OIDC トークンの発行に必須

steps:
  - uses: google-github-actions/auth@v2
    with:
      workload_identity_provider: <terraform output workload_identity_provider の値>
      service_account: <terraform output github_deployer_service_account_email の値>
```

デプロイを許可する対象は `github_repository` と `github_allowed_ref` で絞っています（既定は `maki-engineer/discord-bot` の `refs/heads/main`）。別のブランチから実行すると認証に失敗します。

## 権限について

CI では長期保存したサービスアカウントキーを使わず、Workload Identity Federation を利用します。ローカルでは Application Default Credentials を使います。

Terraform を実行する人には、管理対象リソースの作成・更新権限が必要です。プロジェクトの Owner を使わずに済ませる場合は、次のロールの組み合わせが目安です。

- `roles/run.admin`
- `roles/artifactregistry.admin`
- `roles/secretmanager.admin`
- `roles/iam.serviceAccountAdmin`
- `roles/iam.workloadIdentityPoolAdmin`
- `roles/resourcemanager.projectIamAdmin`
- `roles/serviceusage.serviceUsageAdmin`
- `roles/storage.admin`（State バケット用。バケット単位に絞るのが望ましい）

## 未対応の項目

Terraform 側ではなく、Backend 側で対応が必要なものです。

- **本番用の Dockerfile が無い** — `backend/Dockerfile` は `go run` で動かす開発用で、`golang:1.25` をそのまま使っているためイメージが大きく、本番向きではありません。マルチステージビルドで静的バイナリだけを `gcr.io/distroless/static` などに載せた `Dockerfile.prod` を用意するのが望ましいです。
- **デプロイ用のワークフローが無い** — `.github/workflows/` には `bot-run.yml` だけがあります。Cloud Run へのデプロイは別途ワークフローを追加するか、`gcloud run deploy` を手動実行する必要があります。
- **ポートが固定されている** — `backend/src/cmd/main.go` が `:8080` を直接指定しています。Cloud Run は `PORT` 環境変数でポートを指示する仕様なので、`os.Getenv("PORT")` を見て、未設定なら 8080 にフォールバックする形にしておくと安全です。現状は Terraform 側で `container_port = 8080` を明示しているため動作します。
- **ヘルスチェック用のエンドポイントが無い** — `/healthz` のような軽量なエンドポイントを用意すると、Cloud Run の起動プローブを設定できます。現状は Terraform 側でプローブを設定していません（既定のTCPチェックが使われます）。

## 注意事項

- `terraform destroy` は Cloud Run や Artifact Registry を削除するため、通常の開発手順では実行しません。Cloud Run には `deletion_protection = true`、State バケットには `prevent_destroy = true` を設定しています。
- Artifact Registry のクリーンアップポリシーは、初回は `artifact_registry_cleanup_dry_run = true`（ドライラン）で入ります。Artifact Registry の画面で削除対象を確認してから `false` にしてください。
- `cloud_run_allow_unauthenticated` の既定は `false` です。Backend の `/api/members` はメンバーの氏名と誕生日を返すため、公開してよいかを判断してから変更してください。**現状すでに公開されている場合、`false` のまま `apply` すると公開アクセスが外れて呼び出せなくなります。**手順4のコマンドで現状を確認してください。
- State、`terraform.tfvars`、`*.tfplan` は Git に追加しません（`.gitignore` 済み）。`.terraform.lock.hcl` はプロバイダのバージョンを固定するため、意図的にコミットします。
