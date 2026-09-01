# revloop

[![ci](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml/badge.svg)](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[English](README.md) ・ 日本語

AI によるレビューと修正のループを収束するまで繰り返すワークフローを実現する Claude Code / Codex 対応プラグインです。レビューのループ回数の増加を防止するフェンス機構を整備し、処理時間やトークン消費を抑えるように設計されています。

コマンドは以下の2種が利用可能です。

- `/revloop:review-loop`: リモート動作。レビュアー bot を GitHub 上で呼び出す。
- `/revloop:review-loop-local`: ローカル動作。お使いのマシン上で動作するレビューコマンドを利用する。

**リモート動作のループは、レビュアーが既に応答することを前提にします。** 選択したレビュアー
（codex・claude・gemini・カスタムのいずれか）の GitHub 連携がリポジトリにインストール済みで、
コメントに応答する状態になっている必要があります。

**ローカル動作のループは、Github 上のコメント欄にはアクセスしません。** また、ローカルの
レビュアーはコードを書いたモデルと同一である場合があり、効果的な第三者レビューが実現できない
場合があります。詳細は [`docs/design-notes.md`](docs/design-notes.md) を参照してください。

基本的な実行コマンドは以下の通りです。

```console
/revloop:review-loop
/revloop:review-loop --reviewer gemini --max-rounds 15
/revloop:review-loop --merge --auto

/revloop:review-loop-local
/revloop:review-loop-local --reviewer ecc-review-pr --accept-at HIGH
```

## 動作の流れ

処理は数十分程度かかることが多いです。 **大半は、レビュアーの応答待ち時間です**。

| フェーズ     | ステップ | 内容                                                                                                           | 目安の時間          |
| ------------ | -------- | -------------------------------------------------------------------------------------------------------------- | ------------------- |
| **解決**     | 1        | リポジトリを探索し、`source` 列付きの設定表を構築する。                                                        | 数秒                |
| **準備**     | 2–6      | topic branch を切り、検証コマンドを実行、コミットし (**1 つ目の停止点**)、push して PR を作る                  | 3分                 |
| **トリガー** | 7        | レビュー依頼のコメントを投稿する。`revloop:trigger` マーカーにレビュアー・bot・head の sha・ラウンドを記録する | 数秒                |
| **待機**     | 8        | **今回の**トリガーに対する結果が表示されるまで GitHub をポーリングする                                         | **数分 — 下記参照** |
| **判定**     | 9        | continue / finish / abort を判定する                                                                           | 数秒                |
| **修正**     | 10–11    | inline の指摘を読んで修正し、すべての指摘に返信する                                                            | 数分                |
| **完了**     | 12       | 完了報告を行う。`--merge` が設定されている場合、 CI の green を待ってからマージする (**2 つ目の停止点**)       | CI 次第             |

1 件でも修正を行った場合はステップ 11 からステップ 3に戻り、次のラウンドが始まります。
`--auto` オプションを設定することで、2つの停止点で止まらずに自動でループを続行できます。

待ち時間の目安は、選んだレビュアーの[カード](reviewers/)に計測値として記録しています。API の
利用制限等によりレビューが失敗した場合、ループは abort します。

判定できる応答が返らないまま待機の上限に達した場合、ループは abort する前にトリガーを 1 回だけ
再投稿します。そのため 1 ラウンドに対してレビュー依頼のコメントが 2 件並ぶことがあります。発動条件と、
それが安全である理由は [`docs/design-notes.md`](docs/design-notes.md) に記載しています。

## 導入

詳細は [`docs/install.md`](docs/install.md) を参照してください。

### Claude Code

```console
/plugin marketplace add iwmaeda/revloop
/plugin install revloop@revloop
```

同時に、必要な作業の権限を許可してください。`.claude/settings.local.json` に以下を追加します。詳細は [`docs/permissions.md`](docs/permissions.md) を参照してください。

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
      "Bash(gh repo view:*)",
      "Bash(git:*)"
    ]
  }
}
```

### Codex

```console
git clone https://github.com/iwmaeda/revloop.git ~/.revloop
mkdir -p .agents/skills
cp -r ~/.revloop/.agents/skills/revloop .agents/skills/
export REVLOOP_PROCEDURE=~/.revloop/commands/review-loop.md
```

Codex では権限は承認ポリシーとサンドボックスで制御します。詳細は [`docs/permissions.md`](docs/permissions.md) を参照してください。

## 設定

デフォルトでは、revloop はベースブランチ・検証コマンド・ブランチ接頭辞・コミット
規約をリポジトリ自身から検出し、`source` 列付きの設定表を作成します:

```text
key              value                              source
reviewer         codex                              flag
baseBranch       main                               detected
verify           npm run check:all, npm test        detected
commitStyle      conventional (en)                  detected
maxRounds        10                                 builtin
```

設定を変更したり、独自のレビュアーを追加したい場合は `.revloop.json` を作成してください。
詳細は [`docs/configuration.md`](docs/configuration.md) および [`docs/adding-a-reviewer.md`](docs/adding-a-reviewer.md) を参照してください。

```json
{
  "version": 1,
  "project": { "verify": ["make check", "make test"] },
  "reviewers": {
    "acme": {
      "trigger": "@acme review",
      "botLogin": "acme-reviewer[bot]",
      "cleanPatterns": ["^Acme Review: no issues found"]
    }
  }
}
```

## 過剰なループの防止

**LLM によるコードレビューでは些細な指摘が延々と出力されがちです。** そのような指摘によりループが不必要に長期化することを防ぐため、`--accept-at <level>` オプションが用意されています。

```console
/revloop:review-loop-local --reviewer ecc-review-pr --accept-at HIGH   # CRITICAL だけがブロックする
```

`--accept-at <level>` フラグで**未修正のまま残してよい最上位の深刻度（severityLevels）**を指定します。それより深刻度の高い指摘がすべて修正された時点でループは収束可能となります。

## 対応済みレビュアー

| プリセット      | 種別             | トリガー / コマンド               | ステータス |
| --------------- | ---------------- | --------------------------------- | ---------- |
| `codex`         | `github-comment` | `@codex review`                   | verified   |
| `gemini`        | `github-comment` | `@gemini review` (カード参照)     | verified   |
| `claude`        | `github-comment` | `@claude review`                  | unverified |
| `code-review`   | `local-command`  | `claude -p "/code-review medium"` | unverified |
| `ecc-review-pr` | `local-command`  | `ecc:review-pr`                   | unverified |

各[カード](reviewers/)には計測内容・計測日時・出典が記録されています。現時点で copilot
(reviewer request でレビュー依頼)には対応していません。

## 対応していないこと

以下の点については課題が残っています。

| 制限                                   | 理由                                                                                          |
| -------------------------------------- | --------------------------------------------------------------------------------------------- |
| **fork では動かない**                  | PR が upstream 側にあるため、誤ったリポジトリを対象としてしまいます。step 1 で abort します。 |
| **同一リポジトリの topic branch のみ** | 1 ブランチにつき open PR 1 本が対象です。PR が同定できない場合は abort します。               |
| **マージは merge commit のみ**         | squash と rebase は使えません。                                                               |
| **`copilot` 非対応**                   | コメントによるトリガーを持たず、reviewer-request 経路が未実装です。                           |
| **ローカルループは push しない**       | コミットまでで終了します。push と PR 作成は手動で行うか、リモート側のループを回してください。 |

## ドキュメント

| ガイド                                                       | 内容                                             |
| ------------------------------------------------------------ | ------------------------------------------------ |
| [Install](docs/install.md)                                   | 前提、Claude Code、Codex、必要な作業、導入の確認 |
| [Permissions](docs/permissions.md)                           | Claude Code の許可ルール、 Codex の承認設定      |
| [Configuration](docs/configuration.md)                       | `.revloop.json` のリファレンス                   |
| [Adding a reviewer](docs/adding-a-reviewer.md)               | Custom reviewer の設定方法                       |
| [Design notes](docs/design-notes.md)                         | レビューループの設計                             |
| [Known environment quirks](docs/known-environment-quirks.md) | 既知の制限事項やバグなど                         |
| [Contributing](CONTRIBUTING.md)                              | チェックの実行方法、フェンス編集時の手順         |
| [Code of conduct](CODE_OF_CONDUCT.md)                        | 開発指針                                         |
| [Security](SECURITY.md)                                      | セキュリティ関係の留意事項                       |
| [English README](README.md)                                  | 英語版 README                                    |

## ライセンス

MIT
