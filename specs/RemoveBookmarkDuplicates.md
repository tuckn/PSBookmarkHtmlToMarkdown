# RemoveBookmarkDuplicates — Remove duplicates of output Bookmark Markdown

`Conver-tBookmarkHtmlToMarkdown`で出力されたMarkdownファイルを読み込み、重複するURLを持つファイルを削除する。

- Status: Draft
- Owner: @tuckn
- Links: modules/RemoveBookmarkDuplicates.psm1, scripts/RemoveBookmarkDuplicates.ps1, tests/RemoveBookmarkDuplicates.Tests.ps1

## 1. Summary (Introduction)

指定したフォルダ内にある`Conver-tBookmarkHtmlToMarkdown`で出力されたMarkdownファイルをすべて読み込み、`url`が重複しているファイルを削除する。

## 2. Intent (User Story / Goal)

As a user practicing PKM (Personal Knowledge Management),
I would like to organize the bookmark Markdown files output by the module `Conver-tBookmarkHtmlToMarkdown` in this repository.
So that I want to remove the bookmark Markdown file showing the same URL.

## 3. Scope

### In-Scope

- PowerShellモジュール（.psm1）とそれをラッパーするスクリプト（.ps1）の提供
- PowerShellスクリプト（.ps1）をラッパーするCMDスクリプト（.cmd）の提供
- テストスクリプトの提供

### Non-Goals

## 4. Contract (API / CLI / Data)

### 4.1 Module API

| Param       | Type            | Req | Default | Notes |
|-------------|-----------------|-----|---------|-------|
| `-Path`     | string          | ✓   | --      | 対象の.mdが格納されているフォルダ |
| `-Recursive` | switch      | —   | false       | trueでサブフォルダの.mdファイルも対象とする |
| `-Passthru`      | switch        | —   | false   | 削除したファイル名、アイコンファイル名を表示 |

### 4.2 Wrapper CLI

**`scripts/RemoveBookmarkDuplicates.ps1`**

- 受け取る引数は、Module APIと同等。

**`scripts/cmd/RemoveBookmarkDuplicates.cmd`**

- 受け取ったすべての引数を.ps1スクリプトに渡す

### 4.3 Data Spec

#### Example: Markdownファイル（.md）

```yaml
---
title: "Mapify"
description: 
url: "https://mapify.so/ja/app/new"
linkStatus: ""
medium: "web"
site: 
domain: "mapify.so"
favicon: "icons/mapify.so_new.png"
cover: 
author: 
published: 
keywords:
  - "[[IT (information technology)]]"
  - "[[AI (artificial intelligence)]]"
cliptool: "HTML exported from a browser"
space: "personal"
status: "inbox"
type: "literature"
date: "2024-11-24T065928+0900"
updated: "2024-11-24T065928+0900"
noteId: "d8c2cac0-99fe-47e2-93b9-0d3916a3ec6d"
---

```

## 5. Rules & Invariants

### `modules/RemoveBookmarkDuplicates.psm1`

- **MUST** 指定されたフォルダ内のすべてのMarkdownファイルのFrontmatterを読み込み、同一の`url`プロバティ値をもつファイルを削除する。削除する際、`date`プロバティが最も古いファイルを残す。同一であった場合、ファイル名がもっとも短い方を残す。ファイル名文字数も同じならば、残すのはどっちでもよい。なお、`data`が空である場合、残す最優先がもっとも低い（優先的に削除）。
- **MUST** 削除されるMarkdownファイルが`favicon`プロバティに値を持つ場合、そのアイコンファイル自体も削除する。アイコンファイルのパスは、削除対象のMarkdownファイルの`favicon`プロバティに記載されている。相対パスの場合、削除対象のMarkdownファイルがあるパスをカレントとする。
  - 例: `favicon: "icons/mapify.so_new.png"`ならば、`"<削除対象のMarkdownファイルのパス>/icons/mapify.so_new.png"`となる。
  - 絶対パスはそのまま削除する。
- **MUST** URL比較の際、末尾スラッシュ/クエリ/フラグメントなどすべて含めて比較する。
- **MUST** URLの定義がなかったり、ブックマークレットなどは対象外とする。
