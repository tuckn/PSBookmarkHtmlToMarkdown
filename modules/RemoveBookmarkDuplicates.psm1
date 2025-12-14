Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Remove-BookmarkDuplicates {
<#
.SYNOPSIS
Removes duplicate bookmark Markdown files (same url) leaving the oldest date and shortest name.

.DESCRIPTION
Scans the specified folder (and optionally subfolders) for Markdown files produced by Convert-BookmarkHtmlToMarkdown.
Reads frontmatter, groups by url, and deletes all but one file per url (oldest date retained; if dates tie, shortest filename retained).
When a deleted file references a favicon, the favicon file is also removed (relative to the Markdown file when path is relative).

.PARAMETER Path
Directory that contains the Markdown files to evaluate.

.PARAMETER Recursive
Include subdirectories.

.PARAMETER Passthru
Emit objects describing deleted files (Url, RemovedPath, KeptPath, FaviconPath).

.EXAMPLE
Remove-BookmarkDuplicates -Path .\out -Recursive -Passthru -WhatIf

Shows what would be removed when duplicates are resolved in .\out recursively.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [switch] $Recursive,

        [switch] $Passthru
    )

    function Get-Frontmatter {
        param([string] $FilePath)

        try {
            $content = Get-Content -LiteralPath $FilePath -Raw -ErrorAction Stop
        }
        catch {
            return $null
        }

        if (-not ($content -match '(?s)^(?<head>---\s*\r?\n.*?\r?\n---)\s*')) {
            return $null
        }

        $head = $Matches['head']
        $lines = $head -split '\r?\n'
        $props = @{ url = $null; date = $null; favicon = $null }
        foreach ($line in $lines) {
            $m = [regex]::Match($line, '^(?<key>[A-Za-z0-9_-]+):\s*(?<val>.*)$')
            if (-not $m.Success) { continue }
            $key = $m.Groups['key'].Value
            $val = $m.Groups['val'].Value.Trim()
            switch ($key) {
                'url'     { $props.url = ($val.Trim('"')) }
                'date'    { $props.date = ($val.Trim('"')) }
                'favicon' { $props.favicon = ($val.Trim('"')) }
            }
        }

        return [pscustomobject]@{
            Url     = $props.url
            Date    = $props.date
            Favicon = $props.favicon
        }
    }

    function Parse-DatePriority {
        param([string] $DateString)
        if ([string]::IsNullOrWhiteSpace($DateString)) {
            return $null
        }
        try {
            return [datetimeoffset]::Parse($DateString)
        }
        catch {
            return $null
        }
    }

    $resolvedRoot = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $searchOpt = if ($Recursive) { 'Recurse' } else { 'Depth' }

    $mdFiles = Get-ChildItem -LiteralPath $resolvedRoot -Filter '*.md' -File -Recurse:$Recursive
    if (-not $mdFiles) { return }

    $entries = New-Object 'System.Collections.Generic.List[psobject]'
    foreach ($file in $mdFiles) {
        $fm = Get-Frontmatter -FilePath $file.FullName
        if ($null -eq $fm) { continue }
        if ([string]::IsNullOrWhiteSpace($fm.Url)) { continue }
        $dateVal = Parse-DatePriority -DateString $fm.Date
        $entries.Add([pscustomobject]@{
            Path    = $file.FullName
            Url     = $fm.Url
            Date    = $dateVal
            RawDate = $fm.Date
            NameLen = $file.Name.Length
            Favicon = $fm.Favicon
        }) | Out-Null
    }

    $toDelete = New-Object 'System.Collections.Generic.List[psobject]'

    foreach ($group in $entries | Group-Object -Property Url) {
        $candidates = @($group.Group)
        if ($candidates.Count -le 1) { continue }

        $ordered = $candidates | Sort-Object @{Expression = { if ($_.Date) { $_.Date } else { [datetimeoffset]::MaxValue } }}, @{Expression = { $_.NameLen }}, @{Expression = { $_.Path }}
        $keeper = $ordered[0]
        $remove = $ordered[1..($ordered.Count - 1)]
        foreach ($item in $remove) {
            $toDelete.Add([pscustomobject]@{
                Url         = $item.Url
                RemovedPath = $item.Path
                KeptPath    = $keeper.Path
                FaviconPath = $item.Favicon
            }) | Out-Null
        }
    }

    foreach ($item in $toDelete) {
        if ($PSCmdlet.ShouldProcess($item.RemovedPath, 'Remove duplicate bookmark Markdown')) {
            Remove-Item -LiteralPath $item.RemovedPath -Force -ErrorAction SilentlyContinue

            if (-not [string]::IsNullOrWhiteSpace($item.FaviconPath)) {
                $favPath = $item.FaviconPath
                if (-not [System.IO.Path]::IsPathRooted($favPath)) {
                    $favPath = Join-Path (Split-Path -Parent $item.RemovedPath) $favPath
                }
                if (Test-Path -LiteralPath $favPath -PathType Leaf) {
                    Remove-Item -LiteralPath $favPath -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    if ($Passthru -and $toDelete.Count -gt 0) {
        return $toDelete.ToArray()
    }
}

Export-ModuleMember -Function Remove-BookmarkDuplicates
