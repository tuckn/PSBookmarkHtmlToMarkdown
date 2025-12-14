# PSBookmarkHtmlToMarkdown

Browser bookmark (Netscape format) → Obsidian-ready Markdown converter with YAML frontmatter and favicon extraction.

## Requirements

- ~~Windows PowerShell 5.1 (preferred) or~~ PowerShell 7+

## Usage (Script)

This is the HTML file of the bookmarks exported from your browser.

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

Run the following command:

```powershell
.\scripts\ConvertBookmarkHtmlToMarkdown.ps1 -Path .\assets\bookmarks.html -OutputDirectory .\out -Passthru -CheckLinkStatus -SaveFavicon
# Note: `-CheckLinkStatus` option does not work.
```

This will be converted into Markdown files like this:

```yaml
---
title: "最新のデータ ウェアハウスのアーキテクチャ - Azure Solution Ideas | Microsoft Docs"
description:
url: "https://docs.microsoft.com/ja-jp/azure/architecture/solution-ideas/articles/modern-data-warehouse"
linkStatus: "active"
medium: "web"
site:
domain: "microsoft.com"
favicon: "icons/microsoft.com_modern-data-warehouse.png"
cover:
author:
published:
keywords:
  - "[[IT (information technology)]]"
  - "[[cloud computing]]"
  - "[[Azure]]"
cliptool: "HTML exported from a browser"
space: "personal"
status: "inbox"
type: "bookmark"
date: "2022-10-02T15:56:15+09:00"
updated: "2022-10-02T15:56:15+09:00"
noteId: "c1f83755-1ff2-4bea-8bbc-a6af68e33e4e"
---

```

You can also specify a JSON file as an argument.

```json
{
  "Path": "C:\\Users\\you\\Downloads\\bookmarks.html",
  "OutputDirectory": "C:\\Users\\you\\Documents\\Obsidian\\Inbox",
  "Passthru": true,
  "CheckLinkStatus": true,
  "SaveFavicon": true
}
```

```powershell
.\scripts\ConvertBookmarkHtmlToMarkdown.ps1 -ConfigJsonPath .\scripts\config_sample.json
```

### Remove duplicates by URL (keeps oldest date):

Delete files with duplicate `url` from the output Markdown files.

```powershell
.\scripts\RemoveBookmarkDuplicates.ps1 -Path .\out -Recursive -Passthru
```

## Usage (Module)

```powershell
Import-Module (Join-Path $PSScriptRoot 'PSBookmarkHtmlToMarkdown.psd1') -Force
Convert-BookmarkHtmlToMarkdown -Path .\assets\bookmarks.html -OutputDirectory .\out
```

## Output

- One Markdown file per bookmark, UTF-8 (no BOM), with frontmatter fields described in `specs/ConvertBookmarkHtmlToMarkdown.md`.
- Favicons (when present and `-SaveFavicon` is used) are decoded to PNG into an `icons` subfolder next to the Markdown.
- Filenames are sanitized (emoji removed) and truncated to 100 characters before the extension; collisions add `_1`, `_2`, ...

## Testing

```powershell
Invoke-Pester -CI
```

## License

MIT License. See [LICENSE](LICENSE) for details.

Copyright (c) 2025 [Tuckn](https://github.com/tuckn)
