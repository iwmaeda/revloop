# revloop

[![ci](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml/badge.svg)](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[English](README.md) ・ 日本語

AI によるレビューと修正のループを、レビューが収束するまで繰り返す Claude Code プラグインです。
ラウンド数・処理時間・トークン消費が必要以上に増えないよう、ループに歯止めを設けています。

レビュアーごとに専用のコマンドがあります。

| コマンド                      | レビュアー                    | 実行場所           |
| ----------------------------- | ----------------------------- | ------------------ |
| `/revloop:remote-codex-loop`  | `@codex review`               | PR 上の bot        |
| `/revloop:remote-gemini-loop` | `@gemini review`              | PR 上の bot        |
| `/revloop:remote-claude-loop` | `@claude review`              | PR 上の bot        |
| `/revloop:remote-custom-loop` | `--config` で指定した独自定義 | PR 上の bot        |
| `/revloop:local-review-loop`  | Claude Code の `/code-review` | 手元のサブプロセス |
| `/revloop:local-ecc-loop`     | ECC の `/ecc:review-pr`       | 手元のサブプロセス |
| `/revloop:local-custom-loop`  | `--config` で指定した独自定義 | 手元のサブプロセス |

リモート動作のコマンドは、レビュアーの GitHub 連携がリポジトリにインストール済みで、コメントに
応答する状態であることを前提にします。

ローカル動作のコマンドはコメントを投稿せず、マージも行いません。収束したブランチを push して
PR を作成します（`--no-publish` を付けるとコミットで終了）。レビューは既定で `sonnet` で実行され、
`--model` で変更できます。

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

| フラグ             | 対象コマンド    | 既定       | 内容                                    |
| ------------------ | --------------- | ---------- | --------------------------------------- |
| `--rigor <level>`  | すべて          | `standard` | どこまで厳密に修正し切るか（後述）      |
| `--max-rounds <n>` | すべて          | 5 / 3      | 収束しない場合の打ち切り                |
| `--auto`           | すべて          | off        | 停止点で止まらずに進める                |
| `--merge`          | `remote-*`      | off        | 収束後、CI の green を待ってマージする  |
| `--timeout <dur>`  | `remote-*`      | `30m`      | トリガー 1 つあたりの待機上限           |
| `--model <name>`   | `local-*`       | `sonnet`   | レビューを実行するモデル                |
| `--no-publish`     | `local-*`       | off        | コミットで終了し、push も PR も行わない |
| `--config <path>`  | `*-custom-loop` | 必須       | 実行するレビュアー定義ファイル          |

既定が 2 つ並ぶ欄は remote / local の順です。`--max-rounds` の既定は `--rigor` で決まります。

## 動作の流れ

1 回の実行は数十分かかることが多く、その大半はレビュアーの応答待ちです。

| フェーズ     | ステップ | 内容                                                                                 |
| ------------ | -------- | ------------------------------------------------------------------------------------ |
| **解決**     | 1        | リポジトリを調べ、解決した設定を表示する                                             |
| **準備**     | 2–6      | topic branch を切り、検証を実行し、コミットし（1 つ目の停止点）、push して PR を作る |
| **トリガー** | 7        | レビュー依頼のコメントを投稿する                                                     |
| **待機**     | 8        | 今回のトリガーに対する結果が届くまで GitHub をポーリングする                         |
| **判定**     | 9        | 続行・完了・中断のいずれかを決める                                                   |
| **修正**     | 10–11    | 指摘を読んで修正し、すべての指摘に返信する                                           |
| **完了**     | 12       | 報告する。`--merge` 指定時は CI の green を待ってマージする（2 つ目の停止点）        |

指摘を 1 件でも修正した場合はステップ 3 に戻り、次のラウンドに入ります。`--auto` を付けると 2 つの
停止点で止まらずに進みます。利用制限などで中断した場合は、原因が解消してから同じコマンドを再実行すれば再開できます。

### ローカル動作のループ

| フェーズ     | ステップ    | 内容                                                          |
| ------------ | ----------- | ------------------------------------------------------------- |
| **解決**     | 1           | レビューに使うモデルを含め、解決した設定を表示する            |
| **準備**     | 2–4         | topic branch を切り、検証を実行し、コミットする（停止点）     |
| **公開**     | 5 または 10 | push し、PR がなければ作成する                                |
| **レビュー** | 6           | レビューコマンドを実行し、出力を読む                          |
| **判定**     | 7–8         | 次に行うことを決める                                          |
| **修正**     | 9           | 指摘を修正し、誤った指摘には理由を示す                        |
| **完了**     | 11          | 報告し、`--no-publish` でなければその内容を PR 本文に書き込む |

PR を読むレビュアーの場合は毎ラウンドのレビュー前に公開し（ステップ 5）、それ以外のレビュアーの
場合は収束後に 1 度だけ公開します（ステップ 10）。`--no-publish` を付けるとどちらも行いません。

## 導入

詳細は [`docs/install.md`](docs/install.md) を参照してください。

### Claude Code

```console
/plugin marketplace add iwmaeda/revloop
/plugin install revloop@revloop
```

コマンドの実行には認証済みの `gh` が必要です（`--no-publish` を付けたローカル実行を除く）。

ループに必要な権限を許可するため、`.claude/settings.local.json` に以下を追加してください。詳細は
[`docs/permissions.md`](docs/permissions.md) を参照してください。

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

`codex plugin install` はまだ存在しないため、skill を手で配置します。

```console
git clone https://github.com/iwmaeda/revloop.git ~/.revloop
mkdir -p ~/.agents/skills
cp -r ~/.revloop/.agents/skills/revloop ~/.agents/skills/
```

Codex で使えるのは skill 1 つで、対象は PR ループのみです。Codex 上で最初から最後まで実行した
実績はまだありません。skill は `~/.revloop` から手順書を読み込みます。別の場所に clone した場合は
`ln -s /path/to/your/clone ~/.revloop` でリンクしてください。Codex は許可リストではなく
サンドボックスで権限を制御します。設定は [`docs/permissions.md`](docs/permissions.md) を参照してください。

## 設定

既定では、ベースブランチ・検証コマンド・ブランチ接頭辞・コミット規約をリポジトリから検出し、
値の出どころとあわせて表示します。

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

キーのある値を変えたい場合は `.revloop.json` を作成してください。キーのないフラグは
[`docs/configuration.md`](docs/configuration.md) に一覧があります。独自のレビュアーを追加する場合は
[`docs/adding-a-reviewer.md`](docs/adding-a-reviewer.md) を参照してください。

```json
{
  "version": 1,
  "project": { "verify": ["make check", "make test"] },
  "defaults": { "maxRounds": 15 }
}
```

## 過剰なループの防止

AI によるレビューでは、些細な指摘が延々と出続けることがあります。`--rigor <level>` で
どこまで厳密に修正し切るかを指定し、ループを終えてよい条件を決めます。

| レベル                     | ブロックする深刻度 | 許容できる深刻度 | ラウンド上限 (remote / local) |
| -------------------------- | ------------------ | ---------------- | ----------------------------- |
| `minimal`（最低限）        | `critical`         | `high` 以下      | 3 / 2                         |
| `standard`（適度）**既定** | `critical`・`high` | `medium`・`low`  | 5 / 3                         |
| `thorough`（しっかり）     | すべて             | なし             | 10 / 5                        |
| `exhaustive`（完璧）       | すべて             | なし             | 15 / 8                        |

```console
/revloop:remote-codex-loop --rigor minimal
/revloop:local-ecc-loop --rigor thorough
```

深刻度は、どのレビュアーでも `critical > high > medium > low` の 4 段階に揃えて扱います。深刻度を
出力しないレビュアーの場合は、別プロセスの採点モデルが推定します。収束時には、その変更が
指定レベルに対して十分にレビューされたかを記録します。

## 対応済みレビュアー

各プリセットは定義（`reviewers/<name>.json`）とカード（`reviewers/<name>.md`）で構成されます。

| プリセット      | レビュアー       | 深刻度       | ステータス |
| --------------- | ---------------- | ------------ | ---------- |
| `codex`         | `@codex review`  | P1 / P2 / P3 | verified   |
| `gemini`        | `@gemini review` | P1 / P2 / P3 | verified   |
| `claude`        | `@claude review` | なし         | unverified |
| `code-review`   | `/code-review`   | なし         | unverified |
| `ecc-review-pr` | `/ecc:review-pr` | なし         | unverified |

`verified` は、メンテナーが実際の PR で最初から最後まで動かして確認したこと、`reported` は、誰かが
動作を報告したがここでは再現していないことを示します。独自のレビュアーを追加する方法は [`docs/adding-a-reviewer.md`](docs/adding-a-reviewer.md) を参照してください。

## 対応していないこと

| 制限                                 | 内容                                                                                               |
| ------------------------------------ | -------------------------------------------------------------------------------------------------- |
| fork                                 | 非対応です。どちらのループもステップ 1 で中断します。`--no-publish` を付けたローカル実行は可能です |
| ブランチ                             | 同一リポジトリの topic branch で、1 ブランチにつき open PR 1 本が対象です                          |
| マージ方式                           | merge commit のみです。squash と rebase は使えません                                               |
| コメントトリガーを持たないレビュアー | PR ループでは非対応です（例: GitHub Copilot）。ローカルコマンドはトリガーを必要としません          |
| ローカル動作のループ                 | マージしません。PR は別途マージしてください                                                        |
| ホストとしての Codex                 | プレビューです。skill 1 つ、PR ループのみで、通しで実行した実績はありません                        |

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
| [English README](README.md)                    | 英語版 README                                      |

## ライセンス

MIT
