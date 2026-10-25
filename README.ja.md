# revloop

[![ci](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml/badge.svg)](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[English](README.md) ・ 日本語

AI によるレビューと修正のループを、レビューが収束するまで繰り返す Claude Code プラグインです。
ラウンド数・処理時間・トークン消費が必要以上に増えないよう、ループに歯止めを設けています。

| コマンド                      | レビュアー                    | 実行場所           |
| ----------------------------- | ----------------------------- | ------------------ |
| `/revloop:remote-codex-loop`  | `@codex review`               | PR 上の bot        |
| `/revloop:remote-gemini-loop` | `@gemini review`              | PR 上の bot        |
| `/revloop:remote-claude-loop` | `@claude review`              | PR 上の bot        |
| `/revloop:remote-custom-loop` | `--config` で指定した独自定義 | PR 上の bot        |
| `/revloop:local-review-loop`  | Claude Code の `/code-review` | 手元のサブプロセス |
| `/revloop:local-ecc-loop`     | ECC の `/ecc:review-pr`       | 手元のサブプロセス |
| `/revloop:local-custom-loop`  | `--config` で指定した独自定義 | 手元のサブプロセス |

リモート動作のコマンドには、レビュアーの GitHub 連携がリポジトリにインストール済みで、コメントに
応答する状態が必要です。ローカル動作のコマンドはコメントを投稿せず、マージも行いません。

```console
/revloop:remote-codex-loop
/revloop:remote-gemini-loop --max-rounds 15
/revloop:remote-codex-loop --rigor thorough --merge --auto

/revloop:local-review-loop
/revloop:local-review-loop --no-publish
/revloop:local-review-loop --model opus --max-rounds 3
/revloop:local-ecc-loop --rigor minimal

/revloop:local-custom-loop --config ./my-reviewer.json
```

| フラグ             | 対象コマンド    | 既定               | 内容                                                       |
| ------------------ | --------------- | ------------------ | ---------------------------------------------------------- |
| `--rigor <level>`  | すべて          | `standard`         | どこまで厳密に修正し切るか（後述）                         |
| `--max-rounds <n>` | すべて          | `--rigor` で決まる | 収束しない場合の打ち切り                                   |
| `--auto`           | すべて          | off                | 停止点で止まらずに進める（ローカルのレビュアー確認を除く） |
| `--merge`          | `remote-*`      | off                | 収束後、CI の green を待ってマージする                     |
| `--timeout <dur>`  | `remote-*`      | `30m`              | トリガー 1 つあたりの待機上限                              |
| `--model <name>`   | `local-*`       | `sonnet`           | `{reviewModel}` を含む subprocess レビューのモデル         |
| `--no-publish`     | `local-*`       | off                | コミットで終了し、push も PR も行わない                    |
| `--config <path>`  | `*-custom-loop` | 必須               | 実行するレビュアー定義ファイル                             |

## 動作の流れ

1 回の実行は数十分かかることが多く、その大半はレビュアーの応答待ちです。

### リモート動作のループ

| フェーズ     | ステップ | 内容                                                                                 |
| ------------ | -------- | ------------------------------------------------------------------------------------ |
| **解決**     | 1        | リポジトリを調べ、解決した設定を表示する                                             |
| **準備**     | 2–6      | topic branch を切り、検証を実行し、コミットし（1 つ目の停止点）、push して PR を作る |
| **トリガー** | 7        | レビュー依頼のコメントを投稿する                                                     |
| **待機**     | 8        | 今回のトリガーに対する結果が届くまで GitHub をポーリングする                         |
| **判定**     | 9        | 続行・完了・中断のいずれかを決める                                                   |
| **修正**     | 10–11    | 指摘を読んで修正し、インラインの指摘それぞれに返信する                               |
| **完了**     | 12       | 報告する。`--merge` 指定時は CI の green を待ってマージする（2 つ目の停止点）        |

指摘を修正したラウンドの後は、ステップ 3 に戻ります。一部の指摘を許容する `minimal` と `standard`
では、`--merge --auto` は拒否され、`--merge` は受け入れた指摘を確認するために 1 回止まります。
無人でマージするには `--rigor thorough` を使います。利用制限などで中断した実行は、同じコマンドを
再実行すれば再開します。

### ローカル動作のループ

| フェーズ     | ステップ    | 内容                                                          |
| ------------ | ----------- | ------------------------------------------------------------- |
| **解決**     | 1           | レビューに使うモデルを含め、解決した設定を表示する            |
| **準備**     | 2–4         | topic branch を切り、検証を実行し、コミットする（停止点）     |
| **公開**     | 5 または 10 | push し、PR がなければ作成する                                |
| **レビュー** | 6           | レビューコマンドを実行し、出力を読む                          |
| **判定**     | 7–8         | 次に行うことを決める                                          |
| **修正**     | 9           | 指摘を修正し、見送った指摘と受け入れた指摘は報告に記録する    |
| **完了**     | 11          | 報告し、`--no-publish` でなければその内容を PR 本文に書き込む |

PR なしでは動かないレビュアーでは毎ラウンドの前に公開し（ステップ 5）、それ以外では収束後に
1 度だけ公開します（ステップ 10）。

## 導入

前提とトラブルシューティングは [`docs/install.md`](docs/install.md) にあります。

### Claude Code

```console
/plugin marketplace add iwmaeda/revloop
/plugin install revloop@revloop
```

コマンドの実行には認証済みの `gh` が必要です（`--no-publish` を付けたローカル実行を除く）。
リモート動作のコマンドに必要な権限を `.claude/settings.local.json` に追加してください。ローカル動作の
コマンドに必要なのはその一部で、[`docs/permissions.md`](docs/permissions.md) に一覧があります。

```json
{
  "permissions": {
    "allow": [
      "Bash(gh api repos/{owner}/{repo}/:*)",
      "Bash(gh api -X POST repos/{owner}/{repo}/:*)",
      "Bash(gh api -X PUT repos/{owner}/{repo}/:*)",
      "Bash(gh api -X PATCH repos/{owner}/{repo}/:*)",
      "Bash(gh api --paginate repos/{owner}/{repo}/:*)",
      "Bash(gh api graphql:*)",
      "Bash(gh pr:*)",
      "Bash(gh pr create:*)",
      "Bash(gh pr list:*)",
      "Bash(gh repo view:*)",
      "Bash(git:*)"
    ]
  }
}
```

### Codex（プレビュー）

skill を配置したら、[`docs/permissions.md`](docs/permissions.md#codex-approval-policy-and-sandbox)
に従ってサンドボックスにネットワークアクセスを許可してください。

#### Linux

```console
git clone https://github.com/iwmaeda/revloop.git ~/.revloop
mkdir -p ~/.agents/skills
cp -r ~/.revloop/.agents/skills/revloop ~/.agents/skills/
```

既存の clone を使う場合は、`git clone` の行を `ln -s /path/to/clone ~/.revloop` に置き換えます。

#### Windows (PowerShell)

```powershell
git clone https://github.com/iwmaeda/revloop.git "$HOME\.revloop"
New-Item -ItemType Directory -Force "$HOME\.agents\skills"
Copy-Item -Recurse -Force "$HOME\.revloop\.agents\skills\revloop" "$HOME\.agents\skills"
```

既存の clone を使う場合は、`git clone` の行を
`New-Item -ItemType Junction -Path "$HOME\.revloop" -Target C:\path\to\clone` に置き換えます。

## 設定

ベースブランチ・検証コマンド・ブランチ接頭辞・コミット規約をリポジトリから検出し、値の出どころと
あわせて表示します。

```text
key              value                              source
reviewer         codex (verified)                   builtin
rigor            standard                           builtin
severity source  reviewer                           builtin
baseBranch       main                               detected
verify           npm run check:all, npm test        detected
commitStyle      conventional (en)                  detected
maxRounds        5                                  rigor
```

値を変えるには `.revloop.json` を作成します。`.revloop/config.json` があれば、そちらが代わりに
読まれます。キーの一覧とキーのないフラグは [`docs/configuration.md`](docs/configuration.md) にあります。

```json
{
  "version": 1,
  "project": { "verify": ["make check", "make test"] },
  "defaults": { "maxRounds": 15 }
}
```

## 過剰なループの防止

`--rigor <level>` で、どの深刻度の指摘まで修正し切るかと、ラウンド上限を決めます。

| レベル                     | ブロックする深刻度 | 許容できる深刻度 | ラウンド上限 (remote / local) |
| -------------------------- | ------------------ | ---------------- | ----------------------------- |
| `minimal`（最低限）        | `critical`         | `high` 以下      | 3 / 2                         |
| `standard`（適度）**既定** | `critical`・`high` | `medium`・`low`  | 5 / 3                         |
| `thorough`（しっかり）     | すべて             | なし             | 10 / 5                        |
| `exhaustive`（完璧）       | すべて             | なし             | 15 / 8                        |

深刻度は、どのレビュアーでも `critical > high > medium > low` の 4 段階に揃えて扱います。深刻度を
出力しないレビュアーでは、`minimal` と `standard` の場合に別プロセスの採点モデルが推定します。
収束時には、その変更が指定レベルに対して十分にレビューされたかを記録します。

## 対応済みレビュアー

| プリセット      | レビュアー       | 深刻度       | ステータス |
| --------------- | ---------------- | ------------ | ---------- |
| `codex`         | `@codex review`  | P1 / P2 / P3 | verified   |
| `gemini`        | `@gemini review` | P1 / P2 / P3 | verified   |
| `claude`        | `@claude review` | なし         | unverified |
| `code-review`   | `/code-review`   | なし         | unverified |
| `ecc-review-pr` | `/ecc:review-pr` | なし         | unverified |

独自のレビュアーを追加する方法は [`docs/adding-a-reviewer.md`](docs/adding-a-reviewer.md) を参照してください。

## 対応していないこと

| 制限                                 | 内容                                                                         |
| ------------------------------------ | ---------------------------------------------------------------------------- |
| fork                                 | 非対応（`--no-publish` を付けたローカル実行を除く）                          |
| ブランチ                             | 同一リポジトリの topic branch で、1 ブランチにつき open PR 1 本              |
| マージ方式                           | merge commit のみ                                                            |
| コメントトリガーを持たないレビュアー | リモート動作のコマンドでは非対応（例: GitHub Copilot）                       |
| ホストとしての Codex                 | プレビュー。skill 1 つ、リモート動作のループのみで、通しで実行した実績はない |

## ドキュメント

| ガイド                                         | 内容                                               |
| ---------------------------------------------- | -------------------------------------------------- |
| [Install](docs/install.md)                     | 前提、Claude Code、Codex（プレビュー）、導入の確認 |
| [Permissions](docs/permissions.md)             | Claude Code の許可ルール、Codex のサンドボックス   |
| [Configuration](docs/configuration.md)         | `.revloop.json` のリファレンス                     |
| [Adding a reviewer](docs/adding-a-reviewer.md) | 独自レビュアーの定義とカードの書き方               |
| [Design notes](docs/design-notes.md)           | ループがこの形になっている理由                     |
| [Contributing](CONTRIBUTING.md)                | チェックの実行方法、フェンスの編集手順             |
| [Code of conduct](CODE_OF_CONDUCT.md)          | Contributor Covenant                               |
| [Security](SECURITY.md)                        | 脅威モデル                                         |

## ライセンス

MIT
