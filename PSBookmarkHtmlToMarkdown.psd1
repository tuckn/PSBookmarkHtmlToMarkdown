
@{
    RootModule           = 'PSBookmarkHtmlToMarkdown.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'c0389f0f-8878-4363-865a-c742edca7d5b'
    Author               = 'Tuckn'
    CompanyName          = 'Tuckn.NET'
    Copyright            = '(c) 2025 Tuckn. All rights reserved.'
    Description          = 'Convert browser bookmark HTML exports into Obsidian-ready Markdown with frontmatter.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop')
    NestedModules        = @(
        'modules/ConvertBookmarkHtmlToMarkdown.psm1'
        'modules/RemoveBookmarkDuplicates.psm1'
    )
    FunctionsToExport    = @('Convert-BookmarkHtmlToMarkdown','Remove-BookmarkDuplicates')
    CmdletsToExport      = @()
    AliasesToExport      = @()
    VariablesToExport    = @()
    PrivateData          = @{
        PSData = @{
            Tags       = @('bookmarks','markdown','obsidian','frontmatter','favicon','dedupe','powershell-module')
            ProjectUri = 'https://github.com/tuckn/PSBookmarkHtmlToMarkdown'
            LicenseUri = 'https://github.com/tuckn/PSBookmarkHtmlToMarkdown/blob/main/LICENSE'
        }
    }
}
