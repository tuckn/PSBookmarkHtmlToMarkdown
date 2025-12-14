# PSBookmarkHtmlToMarkdown

Browser bookmark (Netscape format) → Obsidian-ready Markdown converter with YAML frontmatter and favicon extraction.

## Requirements

- Windows PowerShell 5.1 (preferred) or PowerShell 7+

## Usage (Script)

```powershell
.\scripts\ConvertBookmarkHtmlToMarkdown.ps1 -Path .\assets\bookmarks.html -OutputDirectory .\out -Passthru -CheckLinkStatus -SaveFavicon
```

With config file:

```powershell
.\scripts\ConvertBookmarkHtmlToMarkdown.ps1 -ConfigJsonPath .\scripts\config_sample.json
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
