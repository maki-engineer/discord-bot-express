# 235bot

235プロダクションの Discord サーバーで利用する Bot と、Bot のデータを表示・管理する Web アプリケーションです。

## プロジェクト構成

| フォルダ | 役割 | 主な技術 |
| --- | --- | --- |
| `discord-app` | Discord Bot 本体、Bot 用データの管理 | TypeScript, discord.js, Sequelize, PostgreSQL |
| `backend` | メンバー情報などを取得する API | Go, Gin, GORM, PostgreSQL |
| `frontend` | 誕生日メンバーなどを表示する Web UI | Next.js, React, TypeScript |
| `infra` | Cloud Runの構成をTerraformで管理する | Terraform |
| `.github` | CI/CD とレビュー用テンプレート | GitHub Actions |

Bot 用の既存データ、マイグレーション、シーダーは `discord-app` にあります。`backend` は同じ PostgreSQL のデータを API として提供し、`frontend` はその API を利用します。

## 開発環境

- Node.js 22 以上
- Go（`backend/go.mod` のバージョンに対応するもの）
- Docker / Docker Compose
- PostgreSQL（Docker Compose を使う場合は不要）

環境変数は `.env.example` を参考に `.env` を作成してください。Discord のトークンや Google Cloud の認証情報などの秘密情報は、リポジトリへコミットしないでください。

## 起動方法

リポジトリのルートで、必要なサービスを起動します。

```bash
docker compose up --build
```

起動後の主な接続先は次のとおりです。

- Frontend: http://localhost:3000
- Backend API: http://localhost:8080
- Backend Swagger: http://localhost:8080/swagger/index.html
- PostgreSQL（テスト用）: localhost:5433
- VOICEVOX Engine: http://localhost:50021

個別に開発する場合は、各フォルダの README を参照してください。

## 各プロジェクトの詳細

- Discord Bot の機能、技術、コマンド、稼働時間: [`discord-app/README.md`](discord-app/README.md)
- Backend API の構成、エンドポイント、テスト、デプロイ: [`backend/README.md`](backend/README.md)
- Frontend の画面、API 接続、開発方法: [`frontend/README.md`](frontend/README.md)
- Google Cloud の Terraform 管理方針: [`infra/README.md`](infra/README.md)
- GitHub Actions と自動化: [`.github/README.md`](.github/README.md)

## テスト・品質チェック

各プロジェクトのテスト・Lint 手順は、それぞれの README と設定ファイルを参照してください。Backend の詳細な手順は `backend/Taskfile.yml` に定義されています。

## デプロイ

Backend は `.github/workflows/cloud-run-deploy.yml` により、`main` ブランチへの変更時に Google Cloud Run へデプロイされます。Frontend と Discord Bot の運用方法や変更時の注意点は、それぞれの README にまとめています。
