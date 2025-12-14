Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Convert-BookmarkHtmlToMarkdown {
<#
.SYNOPSIS
Converts a Netscape-format bookmark HTML file (Edge/Firefox export) into Obsidian-ready Markdown files.

.DESCRIPTION
Reads the specified bookmark HTML, walks folder/link hierarchy, and writes one Markdown file per bookmark with YAML frontmatter.
Frontmatter contains link status, dates (converted from epoch to JST), keywords derived from folder hierarchy and TAGS, and a generated noteId.
When a bookmark has an ICON data URL, the favicon is decoded to PNG and saved under an icons subfolder next to the Markdown.
Existing filenames are not overwritten; sequential suffixes (_1, _2, ...) are added when collisions occur.

.PARAMETER Path
Path to the exported bookmark HTML file. Resolved with Resolve-Path. Required.

.PARAMETER OutputDirectory
Target directory for generated Markdown (and icons folder). Defaults to the HTML file's directory.

.PARAMETER Passthru
When supplied, emits an object per bookmark with input path, title, output Markdown path, favicon path (if created), and linkStatus.

.EXAMPLE
Convert-BookmarkHtmlToMarkdown -Path .\assets\bookmarks.html -OutputDirectory .\out -Passthru

Processes the given bookmarks export and writes Markdown + favicons into .\out, emitting summary objects.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [string] $OutputDirectory,

        [switch] $Passthru,

        [switch] $CheckLinkStatus,

        [switch] $SaveFavicon
    )

    # region helpers
    function Resolve-FilePath {
        param([string] $Candidate)
        try {
            return (Resolve-Path -LiteralPath $Candidate -ErrorAction Stop).ProviderPath
        }
        catch {
            throw ("The path '{0}' could not be resolved: {1}" -f $Candidate, $_.Exception.Message)
        }
    }

    function Parse-Attributes {
        param([string] $AttributeText)

        $result = @{}
        if ([string]::IsNullOrWhiteSpace($AttributeText)) {
            return $result
        }

        $pattern = '(?<name>[A-Za-z0-9_:-]+)\s*=\s*(?:"(?<dq>[^"]*)"|''(?<sq>[^'']*)''|(?<bare>[^\s>]+))'
        foreach ($m in [regex]::Matches($AttributeText, $pattern)) {
            $name = $m.Groups['name'].Value
            $value = if ($m.Groups['dq'].Success) { $m.Groups['dq'].Value } elseif ($m.Groups['sq'].Success) { $m.Groups['sq'].Value } else { $m.Groups['bare'].Value }
            $result[$name] = [System.Net.WebUtility]::HtmlDecode($value)
        }

        return $result
    }

    function ConvertFrom-UnixToJstString {
        param([AllowNull()][string] $UnixSeconds)

        if ([string]::IsNullOrWhiteSpace($UnixSeconds)) { return '' }
        [long]$sec = 0
        if (-not [long]::TryParse($UnixSeconds, [ref]$sec)) { return '' }

        $dto = [DateTimeOffset]::FromUnixTimeSeconds($sec).ToOffset([TimeSpan]::FromHours(9))
        return $dto.ToString('yyyy-MM-ddTHH:mm:sszzz')
    }

    function Get-DomainFromUrl {
        param([string] $Url)
        try {
            $uri = [Uri]::new($Url)
            $host = $uri.Host
        }
        catch {
            return ''
        }

        if ([string]::IsNullOrWhiteSpace($host)) { return '' }
        $labels = @($host.Split('.') | Where-Object { $_ -ne '' })
        if ($labels.Count -lt 2) { return $host }

        $jpSecondLevel = @('co','ne','or','go','ac','ed','ad','gr','lg')
        $lastIndex = $labels.Count - 1
        $secondIndex = $labels.Count - 2
        $last = $labels[$lastIndex]
        $second = $labels[$secondIndex]

        if ($last -eq 'jp' -and $jpSecondLevel -contains $second -and $labels.Count -ge 3) {
            $start = $labels.Count - 3
            $end = $labels.Count - 1
            return ($labels[$start..$end] -join '.')
        }

        return ($labels[$secondIndex..$lastIndex] -join '.')
    }

    function Get-LastPathSegment {
        param([string] $Url)
        try {
            $uri = [Uri]::new($Url)
            $path = $uri.AbsolutePath
            if ([string]::IsNullOrWhiteSpace($path)) { return '' }
            $trimmed = $path.TrimEnd('/')
            if ($trimmed.Length -eq 0) { return '' }
            $segments = @($trimmed.Split('/') | Where-Object { $_ -ne '' })
            if ($segments.Count -eq 0) { return '' }
            return $segments[$segments.Count - 1]
        }
        catch { return '' }
    }

    function Sanitize-FileComponent {
        param([string] $Text)
        if ($null -eq $Text) { return '' }
        # remove invalid filename characters and control chars
        $clean = $Text -replace '[<>:"/\\|?*\r\n\t]', ''
        $clean = [regex]::Replace($clean, '[\x00-\x1F]', '')
        # drop surrogate pairs (emoji etc.)
        $clean = [regex]::Replace($clean, '[\uD800-\uDFFF]', '')
        # collapse whitespace (any Unicode space)
        $clean = [regex]::Replace($clean, '\s+', ' ')
        # trim trailing/leading spaces and dots (including Unicode spaces)
        $clean = $clean.Trim()
        $clean = $clean.Trim('.')
        return $clean
    }

    function Build-UniqueName {
        param(
            [string] $Directory,
            [string] $BaseName,
            [string] $Extension # includes leading dot
        )

        $candidate = "$BaseName$Extension"
        $counter = 1
        while (Test-Path -LiteralPath (Join-Path $Directory $candidate)) {
            $candidate = ("{0}_{1}{2}" -f $BaseName, $counter, $Extension)
            $counter++
        }
        return $candidate
    }

    function Truncate-BaseName {
        param([string] $BaseName)
        if ($null -eq $BaseName) { return '' }
        if ($BaseName.Length -le 100) { return $BaseName }
        return ($BaseName.Substring(0, 99) + '…')
    }

    function Limit-FullPath {
        param(
            [string] $Directory,
            [string] $BaseName,
            [string] $Extension,
            [int] $MaxLength = 240
        )

        $available = $MaxLength - ($Directory.Length + 1 + $Extension.Length)
        if ($available -lt 1) { return 'file' }
        if ($BaseName.Length -le $available) { return $BaseName }
        if ($available -lt 2) { return 'f' }
        return ($BaseName.Substring(0, $available - 1) + '…')
    }

    function Ensure-Directory {
        param([string] $Directory)
        if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
            New-Item -ItemType Directory -Path $Directory -Force | Out-Null
        }
    }

    function Test-LinkStatus {
        param([string] $Url)

        if ([string]::IsNullOrWhiteSpace($Url)) { return '' }
        $uri = $null
        try { $uri = [Uri]::new($Url) } catch { return '' }
        if ($uri.Scheme -notin @('http','https')) { return '' }

        $isActive = $false
        $timedOut = $false

        $common = @{
            Uri                = $Url
            TimeoutSec         = 10
            MaximumRedirection = 5
            ErrorAction        = 'Stop'
            UseBasicParsing    = $true
        }

        try {
            $resp = Invoke-WebRequest @common -Method Head
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 400) { $isActive = $true }
        }
        catch {
            $hasResponse = ($_.Exception -and $_.Exception.PSObject.Properties['Response'] -and $null -ne $_.Exception.Response)
            if ($_.Exception -and $_.Exception.Message -match 'timed out') {
                $timedOut = $true
            }
            elseif ($hasResponse -and $_.Exception.Response.StatusCode.value__ -eq 405) {
                try {
                    $resp2 = Invoke-WebRequest @common -Method Get -MaximumRedirection 5
                    if ($resp2.StatusCode -ge 200 -and $resp2.StatusCode -lt 400) { $isActive = $true }
                }
                catch {
                    if ($_.Exception -and $_.Exception.Message -match 'timed out') { $timedOut = $true }
                }
            }
        }

        if ($isActive) { return 'active' }
        if ($timedOut) { return 'timeout' }
        return 'dead'
    }

    function Decode-Favicon {
        param(
            [string] $IconDataUrl,
            [string] $IconsDirectory,
            [string] $Domain,
            [string] $LastPath
        )

        if ([string]::IsNullOrWhiteSpace($IconDataUrl)) { return '' }
        $match = [regex]::Match($IconDataUrl, '^data:image/(?<type>png|x-icon|ico);base64,(?<data>[A-Za-z0-9+/=]+)$', 'IgnoreCase')
        if (-not $match.Success) { return '' }

        $base64 = $match.Groups['data'].Value
        $fileBase = Sanitize-FileComponent ("{0}_{1}" -f $Domain, ($LastPath ?? ''))
        if ([string]::IsNullOrWhiteSpace($fileBase)) { $fileBase = $Domain }
        if ([string]::IsNullOrWhiteSpace($fileBase)) { return '' }

        $fileBase = Truncate-BaseName -BaseName $fileBase
        Ensure-Directory -Directory $IconsDirectory
        $fileName = Build-UniqueName -Directory $IconsDirectory -BaseName $fileBase -Extension '.png'
        $targetPath = Join-Path $IconsDirectory $fileName

        try {
            $bytes = [Convert]::FromBase64String($base64)
            [System.IO.File]::WriteAllBytes($targetPath, $bytes)
            return $fileName
        }
        catch {
            return ''
        }
    }

    function Build-Frontmatter {
        param(
            [string] $Title,
            [string] $Url,
            [string] $LinkStatus,
            [string] $Domain,
            [string] $FaviconRelPath,
            [string[]] $Keywords,
            [string] $DateValue,
            [string] $UpdatedValue,
            [string] $NoteId
        )

        $lines = New-Object 'System.Collections.Generic.List[string]'
        $lines.Add('---') | Out-Null
        $lines.Add(('title: "{0}"' -f ($Title -replace '"','\"'))) | Out-Null
        $lines.Add('description: ') | Out-Null
        $lines.Add(('url: "{0}"' -f ($Url -replace '"','\"'))) | Out-Null
        $lines.Add(('linkStatus: "{0}"' -f $LinkStatus)) | Out-Null
        $lines.Add('medium: "web"') | Out-Null
        $lines.Add('site: ') | Out-Null
        $lines.Add(('domain: "{0}"' -f $Domain)) | Out-Null
        if ([string]::IsNullOrWhiteSpace($FaviconRelPath)) {
            $lines.Add('favicon: ') | Out-Null
        }
        else {
            $lines.Add(('favicon: "{0}"' -f $FaviconRelPath)) | Out-Null
        }
        $lines.Add('cover: ') | Out-Null
        $lines.Add('author: ') | Out-Null
        $lines.Add('published: ') | Out-Null
        $lines.Add('keywords:') | Out-Null
        foreach ($kw in $Keywords) {
            $lines.Add(('  - "[[{0}]]"' -f ($kw -replace '"','\"'))) | Out-Null
        }
        if ($Keywords.Count -eq 0) {
            $lines.Add('  - ""') | Out-Null
        }
        $lines.Add('cliptool: "HTML exported from a browser"') | Out-Null
        $lines.Add('space: "personal"') | Out-Null
        $lines.Add('status: "inbox"') | Out-Null
        $lines.Add('type: "literature"') | Out-Null
        $lines.Add(('date: "{0}"' -f $DateValue)) | Out-Null
        $lines.Add(('updated: "{0}"' -f $UpdatedValue)) | Out-Null
        $lines.Add(('noteId: "{0}"' -f $NoteId)) | Out-Null
        $lines.Add('---') | Out-Null
        return [string]::Join("`n", $lines)
    }

    function Add-UniqueKeyword {
        param(
            [System.Collections.Generic.List[string]] $List,
            [string] $Keyword
        )
        if ([string]::IsNullOrWhiteSpace($Keyword)) { return }
        if (-not $List.Contains($Keyword)) { $List.Add($Keyword) | Out-Null }
    }

    function Parse-BookmarkTree {
        param([string[]] $Lines)

        $index = 0
        while ($index -lt $Lines.Length -and ($Lines[$index] -notmatch '<DL')) { $index++ }

        $root = [pscustomobject]@{ Type = 'Root'; Title = ''; Tags = @(); Children = New-Object 'System.Collections.Generic.List[psobject]'; Toolbar = $false }

        function Parse-DL {
            param(
                [string[]] $AllLines,
                [ref] $Idx,
                [pscustomobject] $Parent
            )

            while ($Idx.Value -lt $AllLines.Length) {
                $line = $AllLines[$Idx.Value].Trim()
                if ($line -match '^</DL') { $Idx.Value++; break }

                $h3 = [regex]::Match($line, '<DT><H3(?<attrs>[^>]*)>(?<title>.*?)</H3>', 'IgnoreCase')
                if ($h3.Success) {
                    $attrs = Parse-Attributes -AttributeText $h3.Groups['attrs'].Value
                    $folder = [pscustomobject]@{
                        Type      = 'Folder'
                        Title     = [System.Net.WebUtility]::HtmlDecode($h3.Groups['title'].Value.Trim())
                        AddDate   = $attrs['ADD_DATE']
                        LastMod   = $attrs['LAST_MODIFIED']
                        Icon      = $attrs['ICON']
                        Tags      = @()
                        Toolbar   = ($attrs['PERSONAL_TOOLBAR_FOLDER'] -eq 'true')
                        Children  = New-Object 'System.Collections.Generic.List[psobject]'
                    }
                    if ($attrs.ContainsKey('TAGS')) {
                        $folder.Tags = ($attrs['TAGS'] -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    }
                    $Parent.Children.Add($folder) | Out-Null
                    $Idx.Value++
                    if ($Idx.Value -lt $AllLines.Length -and $AllLines[$Idx.Value].Trim().StartsWith('<DL')) {
                        $Idx.Value++
                        Parse-DL -AllLines $AllLines -Idx $Idx -Parent $folder
                    }
                    continue
                }

                $a = [regex]::Match($line, '<DT><A(?<attrs>[^>]*)>(?<title>.*?)</A>', 'IgnoreCase')
                if ($a.Success) {
                    $attrs = Parse-Attributes -AttributeText $a.Groups['attrs'].Value
                    $link = [pscustomobject]@{
                        Type    = 'Link'
                        Title   = [System.Net.WebUtility]::HtmlDecode($a.Groups['title'].Value.Trim())
                        Url     = $attrs['HREF']
                        AddDate = $attrs['ADD_DATE']
                        LastMod = $attrs['LAST_MODIFIED']
                        Icon    = $attrs['ICON']
                        Tags    = @()
                    }
                    if ($attrs.ContainsKey('TAGS')) {
                        $link.Tags = ($attrs['TAGS'] -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    }
                    $Parent.Children.Add($link) | Out-Null
                    $Idx.Value++
                    continue
                }

                $Idx.Value++
            }
        }

        # move index to first DL content
        if ($index -lt $Lines.Length) { $index++ }
        Parse-DL -AllLines $Lines -Idx ([ref]$index) -Parent $root
        return $root
    }

    function Collect-Bookmarks {
        param(
            [pscustomobject] $Node,
            [string[]] $AncestorKeywords
        )

        $results = New-Object 'System.Collections.Generic.List[psobject]'
        foreach ($child in $Node.Children) {
            if ($child.Type -eq 'Folder') {
                $nextKeywords = New-Object 'System.Collections.Generic.List[string]'
                $AncestorKeywords | ForEach-Object { $nextKeywords.Add($_) | Out-Null }
                if (-not $child.Toolbar) {
                    Add-UniqueKeyword -List $nextKeywords -Keyword $child.Title
                }
                foreach ($tag in $child.Tags) { Add-UniqueKeyword -List $nextKeywords -Keyword $tag }
                $inner = Collect-Bookmarks -Node $child -AncestorKeywords $nextKeywords
                if ($null -ne $inner) {
                    $results.AddRange([psobject[]]$inner) | Out-Null
                }
            }
            elseif ($child.Type -eq 'Link') {
                $kws = New-Object 'System.Collections.Generic.List[string]'
                foreach ($k in $AncestorKeywords) { Add-UniqueKeyword -List $kws -Keyword $k }
                foreach ($tag in $child.Tags) { Add-UniqueKeyword -List $kws -Keyword $tag }

                $results.Add([pscustomobject]@{
                    Title   = $child.Title
                    Url     = $child.Url
                    AddDate = $child.AddDate
                    LastMod = $child.LastMod
                    Icon    = $child.Icon
                    Keywords = $kws.ToArray()
                }) | Out-Null
            }
        }
        return $results.ToArray()
    }
    # endregion helpers

    $resolvedHtmlPath = Resolve-FilePath -Candidate $Path
    if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        $targetDirectory = Split-Path -Parent $resolvedHtmlPath
    }
    else {
        if (Test-Path -LiteralPath $OutputDirectory) {
            $targetDirectory = (Resolve-Path -LiteralPath $OutputDirectory -ErrorAction Stop).ProviderPath
        }
        else {
            $targetDirectory = Join-Path -Path (Get-Location).ProviderPath -ChildPath $OutputDirectory
        }
        Ensure-Directory -Directory $targetDirectory
    }

    try {
        $htmlContent = Get-Content -LiteralPath $resolvedHtmlPath -Raw -ErrorAction Stop
    }
    catch {
        throw ("Failed to read HTML file '{0}': {1}" -f $resolvedHtmlPath, $_.Exception.Message)
    }

    $lines = $htmlContent -split "`n"
    $tree = Parse-BookmarkTree -Lines $lines
    $bookmarks = Collect-Bookmarks -Node $tree -AncestorKeywords @()
    $dedup = New-Object 'System.Collections.Generic.List[psobject]'
    $seen = @{}
    foreach ($bm in $bookmarks) {
        $key = "{0}|{1}|{2}" -f $bm.Url, $bm.Title, $bm.AddDate
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $dedup.Add($bm) | Out-Null
        }
    }
    $bookmarks = $dedup.ToArray()

    $iconsDir = Join-Path $targetDirectory 'icons'
    $outputs = New-Object 'System.Collections.Generic.List[psobject]'

    foreach ($bm in $bookmarks) {
        $domain = Get-DomainFromUrl -Url $bm.Url
        $lastPath = Get-LastPathSegment -Url $bm.Url

        $dateString = ConvertFrom-UnixToJstString -UnixSeconds $bm.AddDate
        $updatedString = ConvertFrom-UnixToJstString -UnixSeconds ($bm.LastMod ?? $bm.AddDate)
        if ([string]::IsNullOrWhiteSpace($updatedString)) { $updatedString = $dateString }

        $noteId = [guid]::NewGuid().ToString().ToLowerInvariant()

        $linkStatus = ''
        if ($CheckLinkStatus.IsPresent) {
            $linkStatus = Test-LinkStatus -Url $bm.Url
        }

        $faviconFile = ''
        if ($SaveFavicon.IsPresent) {
            $faviconFile = Decode-Favicon -IconDataUrl $bm.Icon -IconsDirectory $iconsDir -Domain $domain -LastPath $lastPath
        }
        $faviconRel = if ([string]::IsNullOrWhiteSpace($faviconFile)) { '' } else { ("icons/{0}" -f $faviconFile) }

        $keywords = $bm.Keywords
        $frontmatter = Build-Frontmatter -Title $bm.Title -Url $bm.Url -LinkStatus $linkStatus -Domain $domain -FaviconRelPath $faviconRel -Keywords $keywords -DateValue $dateString -UpdatedValue $updatedString -NoteId $noteId

        $baseParts = @()
        $dateForName = if (-not [string]::IsNullOrWhiteSpace($dateString)) { $dateString } else { 'undated' }
        $dateForName = $dateForName -replace ':', '' -replace '-', '' -replace 'T', 'T'
        $baseParts += $dateForName
        $baseParts += (Sanitize-FileComponent -Text $domain)
        $baseParts += (Sanitize-FileComponent -Text $bm.Title)
        $baseJoined = ($baseParts -join '_')
        $baseJoined = Truncate-BaseName -BaseName $baseJoined
        if ([string]::IsNullOrWhiteSpace($baseJoined)) { $baseJoined = 'untitled' }

        $baseJoined = Limit-FullPath -Directory $targetDirectory -BaseName $baseJoined -Extension '.md' -MaxLength 240

        $fileName = Build-UniqueName -Directory $targetDirectory -BaseName $baseJoined -Extension '.md'
        $markdownPath = Join-Path $targetDirectory $fileName

        $content = $frontmatter + "`n`n"

        if ($PSCmdlet.ShouldProcess($markdownPath, 'Write bookmark Markdown')) {
            [System.IO.File]::WriteAllText($markdownPath, $content, (New-Object System.Text.UTF8Encoding($false)))
        }

        if ($Passthru.IsPresent) {
            $outputs.Add([pscustomobject]@{
                InputPath    = $resolvedHtmlPath
                Title        = $bm.Title
                MarkdownPath = $markdownPath
                FaviconPath  = if ([string]::IsNullOrWhiteSpace($faviconFile)) { '' } else { (Join-Path $iconsDir $faviconFile) }
                LinkStatus   = $linkStatus
            }) | Out-Null
        }
    }

    if ($Passthru.IsPresent) {
        return $outputs.ToArray()
    }
}

Export-ModuleMember -Function Convert-BookmarkHtmlToMarkdown
