Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\PSBookmarkHtmlToMarkdown.psd1') -Force -ErrorAction Stop

Describe 'Convert-BookmarkHtmlToMarkdown' {
    BeforeAll {
        $script:OutDir = Join-Path $PSScriptRoot 'out'
        if (Test-Path -LiteralPath $script:OutDir) {
            Remove-Item -LiteralPath $script:OutDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:OutDir | Out-Null

        $script:FixturePath = Join-Path $PSScriptRoot 'fixtures'
        if (-not (Test-Path -LiteralPath $script:FixturePath)) {
            New-Item -ItemType Directory -Path $script:FixturePath | Out-Null
        }

        $sampleHtml = @'
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks</H1>
<DL><p>
  <DT><H3 ADD_DATE="1700000000" LAST_MODIFIED="1700000300">Tech</H3>
  <DL><p>
    <DT><A HREF="https://example.com/article" ADD_DATE="1700000100" LAST_MODIFIED="1700000200" TAGS="ref,example" ICON="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAocB9oN+1OQAAAAASUVORK5CYII=">Example Article</A>
  </DL><p>
</DL><p>
'@

        $script:SamplePath = Join-Path $script:FixturePath 'sample.html'
        Set-Content -LiteralPath $script:SamplePath -Value $sampleHtml -Encoding utf8
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:OutDir) {
            Remove-Item -LiteralPath $script:OutDir -Recurse -Force
        }
    }

    It 'creates markdown and favicon files with expected frontmatter' {
        $result = Convert-BookmarkHtmlToMarkdown -Path $script:SamplePath -OutputDirectory $script:OutDir -Passthru -SaveFavicon

        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 1

        $mdPath = $result[0].MarkdownPath
        Test-Path -LiteralPath $mdPath | Should -BeTrue

        $content = Get-Content -LiteralPath $mdPath -Raw -ErrorAction Stop
        $content | Should -Match '^---'
        $content | Should -Match 'title: "Example Article"'
        $content | Should -Match 'domain: "example\.com"'
        $content | Should -Match 'keywords:\s*\r?\n  - "\[\[Tech\]\]"'
        $content | Should -Match 'noteId: "[0-9a-f\-]{36}"'

        if ($result[0].FaviconPath) {
            Test-Path -LiteralPath $result[0].FaviconPath | Should -BeTrue
        }
    }
}
