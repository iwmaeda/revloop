# revloop

[![ci](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml/badge.svg)](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[English](README.md) ・ 日本語

AI による PR のレビューと修正のループを収束するまで繰り返すワークフローをワンコマンドで実現する Claude Code / Codex 対応プラグインです。レビューのループ回数の増加を防止するフェンス機構を整備し、処理時間やトークン消費を抑えるように動作します。

**revloop は、レビュアーが既に応答することを前提にします。** 選択したレビュアー
（codex・claude・gemini・カスタムのいずれか）の GitHub 連携がリポジトリにインストール済みで、
コメントに応答する状態になっている必要があります。

基本的な実行コマンドは以下の通りです。

```console
/revloop:review-loop
/revloop:review-loop --reviewer gemini --max-rounds 15
/revloop:review-loop --merge --auto
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

**大規模な変更を含む PR に対しては、レビュー待ちで数十分待機する場合もあります。**
ある PR の連続 10 ラウンドでは、codex のレビューは **3〜8 分** で返ってきました (中央値 4 分 14 秒、[`reviewers/codex.md`](reviewers/codex.md)、2026-08)。

API の利用制限等によりレビューが失敗した場合はループは abort されます。

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

## 対応済みレビュアー

| プリセット | トリガー                      | ステータス |
| ---------- | ----------------------------- | ---------- |
| `codex`    | `@codex review`               | verified   |
| `gemini`   | `@gemini review` (カード参照) | verified   |
| `claude`   | `@claude review`              | unverified |

各[カード](reviewers/)には計測内容・計測日時・出典が記録されています。現時点で copilot
(reviewer request でレビュー依頼)には対応していません。

## 対応していないこと

以下の点については課題が残っています。

| 制限                                   | 理由                                                                                                                           |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| **fork では動かない**                  | `{owner}` が fork 側を指すのに PR は upstream にあるため、すべての呼び出しが誤ったリポジトリを指します。step 1 で abort します |
| **同一リポジトリの topic branch のみ** | 1 ブランチにつき open PR 1 本。detached HEAD はどの PR のことか推測せず abort します                                           |
| **マージは merge commit のみ**         | マージ用フェンスは引数を取らないのでコマンド文字列が変わりません。squash と rebase は使えません                                |
| **`copilot` 非対応**                   | コメントによるトリガーを持たず、reviewer-request 経路は未実装です。                                                            |

## ドキュメント

| ガイド                                                       | 内容                                                     |
| ------------------------------------------------------------ | -------------------------------------------------------- |
| [Install](docs/install.md)                                   | 前提、Claude Code、Codex、必要なもの、導入の確認         |
| [Permissions](docs/permissions.md)                           | Claude Code の許可ルールと Codex の承認設定              |
| [Configuration](docs/configuration.md)                       | `.revloop.json` のリファレンスと、無いときに検出される値 |
| [Adding a reviewer](docs/adding-a-reviewer.md)               | 新しいレビュアーを測り、書き起こす                       |
| [Design notes](docs/design-notes.md)                         | このループがこの形をしている理由                         |
| [Known environment quirks](docs/known-environment-quirks.md) | 規範ではない観測。出所と日付つき                         |
| [Contributing](CONTRIBUTING.md)                              | チェックの回し方と、フェンスを編集するときの手順         |
| [Code of conduct](CODE_OF_CONDUCT.md)                        | Contributor Covenant 2.1                                 |
| [Security](SECURITY.md)                                      | 脅威モデル: 信頼できない設定、信頼できないレビュアー出力 |
| [English README](README.md)                                  | この README の英語版                                     |

## ライセンス

MIT
