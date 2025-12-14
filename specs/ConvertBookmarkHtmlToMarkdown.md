# ConvertBookmarkHtmlToMarkdown — Bookmark HTML to Markdown

EdgeやFirefoxからエクスポートされたブックマークファイル（HTML）をMarkdownファイルに変換する。

- Status: Draft
- Owner: @tuckn
- Links: modules/ConvertBookmarkHtmlToMarkdown.psm1, scripts/ConvertBookmarkHtmlToMarkdown.ps1, tests/ConvertBookmarkHtmlToMarkdown.Tests.ps1

## 1. Summary (Introduction)

EdgeやFirefoxからエクスポートされたブックマークファイル（HTML）を入力として、Markdownファイルに変換する。
このMarkdownファイルはブックマークごとに作成され、Obsidianで活用できるよう、先頭に Frontmatter（YAMLブロック）を持っている。ブックマークファイル（HTML）内にbase64で記載されたfaviconが定義されている場合、.pngファイルで書き出す。モジュール関数（`./modules/ConvertBookmarkHtmlToMarkdown.psm1`）とラッパースクリプト（`scripts/ConvertBookmarkHtmlToMarkdown.ps1` / `scripts/cmd/ConvertBookmarkHtmlToMarkdown.cmd`）の両方を提供する。

## 2. Intent (User Story / Goal)

As a user practicing PKM (Personal Knowledge Management),
I want to manage my bookmarks using Obsidian.
so that I will export the bookmarks from my browser as Markdown and import them into Obsidian.

## 3. Scope

### In-Scope

- 指定されたHTMLファイルの内容を読み取り、Markdownファイルを出力する
- 変換中にブックマークのアドレスにアクセスし、ページの死活を把握する
- ブックマーク定義の`ICON`がある場合、.pngファイルとして出力する
- PowerShellモジュール（.psm1）とそれをラッパーするスクリプト（.ps1）の提供
- PowerShellスクリプト（.ps1）をラッパーするCMDスクリプト（.cmd）の提供
- テストスクリプトの提供

### Non-Goals

## 4. Contract (API / CLI / Data)

### 4.1 Module API

| Param       | Type            | Req | Default | Notes |
|-------------|-----------------|-----|---------|-------|
| `-Path`     | string          | ✓   | --      | HTML file path; resolved via `Resolve-Path` |
| `-OutputDirectory` | string      | —   | —       | 変換後の.mdを出力するパス |
| `-Passthru`      | switch        | —   | false   | Emits objects |

### 4.2 Wrapper CLI

**`scripts/ConvertBookmarkHtmlToMarkdown.ps1`**

- 受け取る引数は、Module APIと同等。

**`scripts/cmd/ConvertBookmarkHtmlToMarkdown.cmd`**

- 受け取ったすべての引数を.ps1スクリプトに渡す

### 4.3 Data Spec

#### Example: ブックマークファイル（.html）

```html
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<!-- This is an automatically generated file.
     It will be read and overwritten.
     DO NOT EDIT! -->
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks</H1>
<DL><p>
    <DT><H3 ADD_DATE="1690095553" LAST_MODIFIED="1754710925" PERSONAL_TOOLBAR_FOLDER="true">Favorites bar</H3>
    <DL><p>
        <DT><H3 ADD_DATE="1664664158" LAST_MODIFIED="1732399196">IT (information technology)</H3>
        <DL><p>
            <DT><H3 ADD_DATE="1670027928" LAST_MODIFIED="1765092096">AI (artificial intelligence)</H3>
            <DL><p>
                <DT><A HREF="https://chat.openai.com/chat" ADD_DATE="1670027754">ChatGPT</A>
            </DL><p>
            <DT><H3 ADD_DATE="1664664178" LAST_MODIFIED="1664664178">cloud computing</H3>
            <DL><p>
                <DT><H3 ADD_DATE="1664664975" LAST_MODIFIED="1664664975" ICON="data:image/png;base64,iVBORw0KGgoAAA......">Azure</H3>
                <DL><p>
                    <DT><A HREF="https://docs.microsoft.com/ja-jp/azure/architecture/solution-ideas/articles/modern-data-warehouse" ADD_DATE="1612317073">最新のデータ ウェアハウスのアーキテクチャ - Azure Solution Ideas | Microsoft Docs</A>
...
..
    </DL><p>
</DL><p>
```

ブックマークファイルの詳細な内容は、`assets/`フォルダ内にある.htmlを参照のこと。

#### Example: 出力されるMarkdownファイル（.md）

上記例の.htmlファイルのAzureを出力した場合、ファイル名`20221002T155615+0900_microsoft.com_最新のデータ ウェアハウスのアーキテクチャ - Azure Solution Ideas Microsoft Docs.md`として出力し、ファイル内容は以下となる。

```yaml
---
title: "最新のデータ ウェアハウスのアーキテクチャ - Azure Solution Ideas | Microsoft Docs"
description:  # 固定
url: "https://docs.microsoft.com/ja-jp/azure/architecture/solution-ideas/articles/modern-data-warehouse"
linkStatus: "active"
medium: "web" # 固定
site: # 固定
domain: "microsoft.com"
favicon: "icons/microsoft.com_modern-data-warehouse.png"
cover:  # 固定
author: # 固定
published: # 固定
keywords:
  - "[[IT (information technology)]]"
  - "[[cloud computing]]"
  - "[[Azure]]"
cliptool: "HTML exported from a browser" # 固定
space: "personal" # 固定
status: "inbox" # 固定
type: "literature" # 固定
date: "2022-10-02T15:56:15+09:00"
updated: "2022-10-02T15:56:15+09:00"
noteId: "c1f83755-1ff2-4bea-8bbc-a6af68e33e4e"
---

```

なお、上記のコメントは出力時には不要。
この時、出力される.mdファイル名は`20221002T155615+0900_microsoft.com_最新のデータ ウェアハウスのアーキテクチャ - Azure Solution Ideas Microsoft Docs.md`、.pngファイル名は、`microsoft.com_modern-data-warehouse.png`

出力するMarkdownファイルの詳細な内容は、`assets/`フォルダ内にある.mdを参照のこと。

## 5. Rules & Invariants

### `modules/ConvertBookmarkHtmlToMarkdown.psm1`

- **変換**
  - **MUST** 作成するMarkdown本文の1行目にFrontmatterを挿入する。
  - **MUST** 作成するFrontmatterの内容は、上記の`#### Example: 出力されるMarkdownファイル（.md）`を参照。
  - **MUST** 上記の`#### Example: 出力されるMarkdownファイル（.md）`で、`# 固定`とコメントされているプロバティは、ブックマークHTMLの内容によらず、そのまま出力する。
  - **MUST** Frontmatterのプロバティ値がない場合、プロバティは残したままスペース一つのみ定義する。例えば、`description: `とする。
  - **MUST** 対象のURLにアクセスし、死活状態を確認し、Frontmatterのプロバティ`linkStatus`に記載する。正常ならば、`active`、そうでなければ、`dead`、`timeout`から選択する。タイムアウトの時間は10秒とし、再試行はしない。ただし、ブックマークレットのような非HTTP URLの場合は、死活状態は確認せず、値は空欄となする。例`linkStatus: `
  - **MUST** ブックマークHTML内の`H3`タグも解析し、階層構造の名前をFrontmatterの`keywords`として登録する。この時、Obsidianのノートリンクとして、`"[[<keyword>]]"`のように、`"`と`[[]]`で囲む。なお、`PERSONAL_TOOLBAR_FOLDER`が`true`でいるノードは対象にしない。
  - **MUST** ブックマークHTML内の`TAGS`がある場合、`,`区切りのキーワードとして扱う。キーワードの重複があれば排除する。
  - **MUST** ブックマークHTML内の`ADD_DATE`を出力するFrontmatterの`date`として出力。`LAST_MODIFIED`を`updated`に出力する。HTML内の表記はエポック秒であると思われる。これを、UTCと解釈し、`yyyy-MM-ddThh:mm:ss+09:00`（日本時間）に変換する。`LAST_MODIFIED`の定義かない場合、`updated`は`ADD_DATE`と同じにする。`ADD_DATE`の定義がない場合、空白とする。例' `date: `
  - **MUST** Frontmatter内の`noteId`は、GUID値を生成し、すべて小文字で設定する。
  - **MUST** Frontmatterを閉じる `---` とMarkdown本文の間に1行の空行を挿入する。

- **faviconファイル出力**
  - **MUST** ブックマークHTML内に`ICON`の定義がある場合、そのbase64値を.png画像に変換し、Markdownファイルの出力先と同じ場所の`icons`フォルダに出力する。保存ファイル名は、Frontmatterの`domain`と`url`の最後のパスを`_`で繋げた名前とする。なおクエリやフラグメントは除外し、`/`で終わる場合は、`domain`のみを名前とする。すでに同名のファイルが保存先のフォルダに存在する場合は、上書きせずファイル名の後ろに`_1`のような連番を付けて対応する。+1ずづ増加。
  - **MUST** プロバティ`favicon`は、`ICON`の定義かない場合は空欄とし、ある場合は、`favicon: "icons/<file name>.png"`とする。

- **ファイル出力**
  - **MUST** 作成するファイル名は、Frontmatterのプロバティである`date`、`domain`、`title`を`_`で繋げたものを適用する。ファイル名に使用できない文字は削除する。すでに同名のファイルが保存先のフォルダに存在する場合は、上書きせずファイル名の後ろに`_1`のような連番を付けて対応する。+1ずづ増加。
  - **MUST** ファイル名が拡張子を含まずに50文字を超える場合、後続を`…`と省略して記載する。
  - **MUST** `-OutputDirectory`の指定がない場合、Inputの.htmlと同じ場所に出力する
  - **MUST** .mdのファイルエンコーディグは、UTF-8 LFでBOMは無し。

- **MUST** `-Passthru`が指定された場合、入力HTMLファイルパス、ブックマークタイトル、出力Markdownファイルパス、.pngファイルを出力する。

**`scripts/ConvertBookmarkHtmlToMarkdown.ps1`**

## 6. Acceptance

### 6.1 Criteria

- `7. Quality (Non-Functional Gates)`に記載しているすべてのGateを満たす
- `README.md`に、現状態の使用方法と仕様の説明が反映されている

### 6.2 Scenarios (Gherkin)

**`modules/ConvertBookmarkHtmlToMarkdown.psm1`**

```gherkin
Scenario: 
  Given ブラウザからエクスポートされたブックマークのHTMLファイル"assets/<file name>.html"
  When 引数`Path`に"assets/<file name>.html"を指定してスクリプトを実行した
  Then HTML内に定義されたブックマークが、個々のMarkdownファイルとして出力される
  And HTML内の`ICON`で定義されたbase64文字列が.pngファイルとして出力される
```

**`scripts/ConvertBookmarkHtmlToMarkdown.ps1`**

```gherkin
Scenario: 引数の値を設定ファイルで受け取る
  Given scripts/config_sample.json
  When 引数に`-ConfigJsonPath <Config File Path>`が指定された
  Then 設定ファイルの値を引数の値として、psd1に渡す。CLI上で直接指定された引数は、そちらを優先する
```

## 7. Quality (Non-Functional Gates)

| Attribute       | Gate                                      |
|-----------------|-------------------------------------------|
| Static analysis | PSScriptAnalyzer 0 errors/warnings        |
| Tests           | `Invoke-Pester -CI` succeeds (pwsh)        |
| Encoding        | Output Markdown file encoded as UTF-8 LF without BOM. PowerShell script file encoded as UTF-8 CRLF with BOM  |
| Idempotence     | Repeated runs with same inputs keep file stable |

## 8. Open Questions


## 9. Decisions & Rationale


## 10. References & Changelog

- 2025-12-14: 新規作成
