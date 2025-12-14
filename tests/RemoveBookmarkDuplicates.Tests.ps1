Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\PSBookmarkHtmlToMarkdown.psd1') -Force -ErrorAction Stop

Describe 'Remove-BookmarkDuplicates' {
    BeforeAll {
        $script:TempRoot = Join-Path $TestDrive 'dedupe'
        New-Item -ItemType Directory -Path $script:TempRoot | Out-Null
    }

    BeforeEach {
        Get-ChildItem -LiteralPath $script:TempRoot -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $script:TempRoot -Force | Out-Null
    }

    It 'removes newer duplicate and its favicon, keeps oldest' {
        $oldPath = Join-Path $script:TempRoot '20220101_old.md'
        $newPath = Join-Path $script:TempRoot '20230101_new.md'
        $favDir = Join-Path $script:TempRoot 'icons'
        New-Item -ItemType Directory -Path $favDir | Out-Null
        $favFile = Join-Path $favDir 'example.com_test.png'
        Set-Content -LiteralPath $favFile -Value 'fake' -Encoding utf8

        @"
---
title: "Example Old"
url: "https://example.com/page"
date: "2022-01-01T00:00:00+09:00"
favicon: "icons/example.com_test.png"
---
body
"@ | Set-Content -LiteralPath $oldPath -Encoding utf8

        @"
---
title: "Example New"
url: "https://example.com/page"
date: "2023-01-01T00:00:00+09:00"
favicon: "icons/example.com_test.png"
---
body
"@ | Set-Content -LiteralPath $newPath -Encoding utf8

        $result = Remove-BookmarkDuplicates -Path $script:TempRoot -Passthru

        Test-Path -LiteralPath $oldPath | Should -BeTrue
        Test-Path -LiteralPath $newPath | Should -BeFalse
        Test-Path -LiteralPath $favFile | Should -BeFalse

        $result | Should -Not -BeNullOrEmpty
        $result[0].RemovedPath | Should -Be $newPath
        $result[0].KeptPath    | Should -Be $oldPath
    }

    It 'prefers dated over undated when same url' {
        $dated = Join-Path $script:TempRoot 'dated.md'
        $undated = Join-Path $script:TempRoot 'undated.md'

        @"
---
title: "Dated"
url: "https://example.com/page2"
date: "2022-05-01T00:00:00+09:00"
---
body
"@ | Set-Content -LiteralPath $dated -Encoding utf8

        @"
---
title: "Undated"
url: "https://example.com/page2"
date: 
---
body
"@ | Set-Content -LiteralPath $undated -Encoding utf8

        Remove-BookmarkDuplicates -Path $script:TempRoot

        Test-Path -LiteralPath $dated | Should -BeTrue
        Test-Path -LiteralPath $undated | Should -BeFalse
    }
}
