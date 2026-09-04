# revloop

[![ci](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml/badge.svg)](https://github.com/iwmaeda/revloop/actions/workflows/ci.yaml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[English](README.md) ・ 日本語

AI によるレビューと修正のループを収束するまで繰り返すワークフローを実現する Claude Code / Codex 対応プラグインです。レビューのループ回数の増加を防止するフェンス機構を整備し、処理時間やトークン消費を抑えるように設計されています。

**リモート動作/ローカル動作、およびレビュアーごとに専用コマンドが用意されています。** 現状、提供している
コマンドは以下の通りです。

| コマンド                      | レビュアー                    | 実行場所           |
| ----------------------------- | ----------------------------- | ------------------ |
| `/revloop:remote-codex-loop`  | `@codex review`               | PR 上の bot        |
| `/revloop:remote-gemini-loop` | `@gemini review`              | PR 上の bot        |
| `/revloop:remote-claude-loop` | `@claude review`              | PR 上の bot        |
| `/revloop:remote-custom-loop` | `--config` で指定した独自定義 | PR 上の bot        |
| `/revloop:local-review-loop`  | Claude Code の `/code-review` | 手元のサブプロセス |
| `/revloop:local-ecc-loop`     | ECC の `/ecc:review-pr`       | 手元のサブプロセス |
| `/revloop:local-custom-loop`  | `--config` で指定した独自定義 | 手元のサブプロセス |

コマンドは 7 つですが、**手順書は 2 つです**。`remote-*` はすべて
[`procedures/remote-loop.md`](procedures/remote-loop.md) を、`local-*` はすべて
[`procedures/local-loop.md`](procedures/local-loop.md) を実行します。コマンドが違うのは、参照する
レビュアー定義と提供するフラグだけであり、入口が 7 つあってもコードパスは 7 つになりません。

**リモート動作のコマンドは、レビュアーが既に応答することを前提にします。** その GitHub 連携が
リポジトリにインストール済みで、コメントに応答する状態になっている必要があります。

**ローカル動作のコマンドは、GitHub 上のコメント欄にはアクセスせず、マージも行いません。** 収束した
ブランチの push および PR 作成までを行います (`--no-publish` を付けた場合はコミットまでで終了)。**レビューは既定で軽量モデル
（`sonnet`、`--model` で変更可）で実行されます。** 詳細は
[`docs/design-notes.md`](docs/design-notes.md) を参照してください。

基本的な実行コマンドは以下の通りです。コマンドごとに使用できるフラグは異なります。

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
| `--auto`           | すべて          | off        | 停止点で止まらずに進行するか            |
| `--merge`          | `remote-*`      | off        | 収束後、CI の green を待ってマージする  |
| `--timeout <dur>`  | `remote-*`      | `30m`      | トリガー 1 つあたりの待機上限           |
| `--model <name>`   | `local-*`       | `sonnet`   | レビューを実行するモデル                |
| `--no-publish`     | `local-*`       | off        | コミットで停止し、push も PR も行わない |
| `--config <path>`  | `*-custom-loop` | 必須       | 実行するレビュアー定義ファイル          |

既定が 2 つ並ぶ欄は remote / local の順です。`--max-rounds` の既定は `--rigor` が供給するため、
レベルを変えると一緒に動きます。

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

### ローカル動作のループ

全体の構成はリモート動作と同様です。待機フェーズがないため、ステップは 11 で完了します。

| フェーズ     | ステップ    | 内容                                                                   |
| ------------ | ----------- | ---------------------------------------------------------------------- |
| **解決**     | 1           | リポジトリを探索し、どのモデルがレビューするかを含めた設定表を表示する |
| **準備**     | 2–4         | topic branch を切り、検証コマンドを実行し、コミットする（**停止点**）  |
| **公開**     | 5 または 10 | push し、PR がなければ作成する                                         |
| **レビュー** | 6           | レビューコマンドを軽量モデルで実行し、その出力を確認する               |
| **判定**     | 7–8         | 指摘を fingerprint 化し、次の作業を決定する                            |
| **修正**     | 9           | 修正および間違った指摘への対応を行う                                   |
| **完了**     | 11          | 報告を行い、公開した場合はその内容を PR 本文に反映する                 |

**2 つの公開ステップのどちらを実行するかは、フラグではなくレビュアーの設定から決まります。** PR を自身
で解決するレビュアーはステップ 5 で毎回のレビュー前に公開し、それ以外のレビュアーは収束後にステップ 10
で一度だけ公開します。先に push すると、既定のレビュアーが差分を取る範囲が空になるためです。
`--no-publish` を指定した場合はどちらも実行しません。

## 導入

詳細は [`docs/install.md`](docs/install.md) を参照してください。

### Claude Code

```console
/plugin marketplace add iwmaeda/revloop
/plugin install revloop@revloop
```

**どちらのコマンドも認証済みの `gh` を必要とします(`--no-publish` を付けた場合を除く)。**

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
      "Bash(gh pr create:*)",
      "Bash(gh pr list:*)",
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
export REVLOOP_PROCEDURE=~/.revloop/procedures/remote-loop.md
```

Codex では権限は承認ポリシーとサンドボックスで制御します。詳細は [`docs/permissions.md`](docs/permissions.md) を参照してください。

## 設定

デフォルトでは、revloop はベースブランチ・検証コマンド・ブランチ接頭辞・コミット
規約をリポジトリ自身から検出し、`source` 列付きの設定表を作成します:

```text
key              value                              source
reviewer         codex                              flag
rigor            standard                           builtin
baseBranch       main                               detected
verify           npm run check:all, npm test        detected
commitStyle      conventional (en)                  detected
maxRounds        5                                  rigor
```

設定を変更したり、独自のレビュアーを追加したい場合は `.revloop.json` を作成してください。
詳細は [`docs/configuration.md`](docs/configuration.md) および [`docs/adding-a-reviewer.md`](docs/adding-a-reviewer.md) を参照してください。

```json
{
  "version": 1,
  "project": { "verify": ["make check", "make test"] },
  "defaults": { "maxRounds": 15 }
}
```

## 過剰なループの防止

**AI によるコードレビューでは些細な指摘が延々と出力されがちです。**
その影響で過剰にループが長期化することを防ぐために、**どこまで厳密に修正し切るか** を指定する
`--rigor <level>` 引数を用意しています。ループの終了判断を担うのはこの引数です。

| レベル                         | ブロックする深刻度 | 許容できる深刻度 | ラウンド上限 (remote / local) | 横展開（sweep）                   |
| ------------------------------ | ------------------ | ---------------- | ----------------------------- | --------------------------------- |
| `minimal`（最低限）            | `critical`         | `high` 以下      | 3 / 2                         | クラス名と既修正チェックのみ      |
| `standard`（適度）　**既定。** | `critical`・`high` | `medium`・`low`  | 5 / 3                         | ＋ corpus                         |
| `thorough`（しっかり）         | すべて             | なし             | 10 / 5                        | 該当するものすべて                |
| `exhaustive`（完璧）           | すべて             | なし             | 15 / 8                        | ＋ input-space を集合として閉じる |

```console
/revloop:remote-codex-loop --rigor minimal
/revloop:local-ecc-loop --rigor thorough
```

深刻度は `severityMap` を通し、全てのレビュワーで `critical > high > medium > low` の4段階で管理されます。
深刻度を出力しないレビュアーに対しては、**別プロセスの採点モデル**が深刻度を推定します。

**収束判定時には、その変更がそのレベルにとって十分にレビューされたかが判定されます。**

## 対応済みレビュアー

各プリセットは **定義**（`reviewers/<name>.json`）と
**カード**（`reviewers/<name>.md`）で構成されます。

| プリセット      | 実行コマンド                  | トリガー / コマンド                                     | severity | ステータス |
| --------------- | ----------------------------- | ------------------------------------------------------- | -------- | ---------- |
| `codex`         | `/revloop:remote-codex-loop`  | `@codex review`                                         | P1/P2/P3 | verified   |
| `gemini`        | `/revloop:remote-gemini-loop` | `@gemini review` (カード参照)                           | P1/P2/P3 | verified   |
| `claude`        | `/revloop:remote-claude-loop` | `@claude review`                                        | なし     | unverified |
| `code-review`   | `/revloop:local-review-loop`  | `claude --model {reviewModel} -p "/code-review medium"` | なし     | unverified |
| `ecc-review-pr` | `/revloop:local-ecc-loop`     | `claude --model {reviewModel} -p "/ecc:review-pr"`      | なし     | unverified |

`{reviewModel}` はコマンド実行前にローカル手順書が展開します。`--model` を指定していればその値が、
指定がなければ `sonnet` が利用されます。

**独自のレビュアーを定義する場合も、定義とカードを作成します。**
詳細は [`docs/adding-a-reviewer.md`](docs/adding-a-reviewer.md) を参照してください。

## 対応していないこと

以下の点については課題が残っています。

| 制限                                     | 理由                                                                                                                                                                     |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **fork では動かない**                    | PR が upstream 側にあるため、誤ったリポジトリを対象としてしまいます。両方のループが step 1 で abort します。ローカルループで `--no-publish` を指定すればループ可能です。 |
| **同一リポジトリの topic branch のみ**   | 1 ブランチにつき open PR 1 本が対象です。PR を検索するループが同定できない場合は abort します。                                                                          |
| **マージは merge commit のみ**           | squash と rebase は使えません。                                                                                                                                          |
| **コメントトリガーを持たないレビュアー** | reviewer request で呼び出されるもの（GitHub Copilot が該当）はコメントを投稿しないため、ラウンドの基準点を固定する対象がなく、step 1 で abort します。                   |
| **ローカルループはマージしない**         | 終着点は push 済みブランチと open PR、`--no-publish` の場合はコミットです。マージは別途行ってください。                                                                  |

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
