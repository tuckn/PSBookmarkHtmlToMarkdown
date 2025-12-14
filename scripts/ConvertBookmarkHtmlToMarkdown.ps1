[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [string] $Path,

    [string] $OutputDirectory,

    [switch] $Passthru,

    [ValidateNotNullOrEmpty()]
    [string] $ConfigJsonPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\PSBookmarkHtmlToMarkdown.psd1') -Force -ErrorAction Stop

$parameterOrder = @('Path','OutputDirectory','Passthru')
$configParameters = @{}

if ($PSBoundParameters.ContainsKey('ConfigJsonPath')) {
    $resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigJsonPath -ErrorAction Stop).ProviderPath
    $configContent = Get-Content -LiteralPath $resolvedConfigPath -Raw -ErrorAction Stop
    $configData = $configContent | ConvertFrom-Json -ErrorAction Stop

    foreach ($name in $parameterOrder) {
        if ($null -ne $configData.$name) {
            $configParameters[$name] = $configData.$name
        }
    }
}

$effective = @{}
foreach ($name in $parameterOrder) {
    if ($configParameters.ContainsKey($name)) {
        $effective[$name] = $configParameters[$name]
    }
}
foreach ($name in $parameterOrder) {
    if ($PSBoundParameters.ContainsKey($name)) {
        $effective[$name] = $PSBoundParameters[$name]
    }
}

foreach ($required in @('Path')) {
    if (-not $effective.ContainsKey($required) -or [string]::IsNullOrWhiteSpace([string]$effective[$required])) {
        throw ("{0} must be provided either via CLI or config file." -f $required)
    }
}

$callParams = @{}
$callParams['Path'] = [string]$effective['Path']
if ($effective.ContainsKey('OutputDirectory')) {
    $callParams['OutputDirectory'] = [string]$effective['OutputDirectory']
}
if ($effective.ContainsKey('Passthru') -and [bool]$effective['Passthru']) {
    $callParams['Passthru'] = $true
}

$control = @{}
foreach ($ctrl in @('WhatIf','Confirm')) {
    if ($PSBoundParameters.ContainsKey($ctrl)) {
        $control[$ctrl] = $PSBoundParameters[$ctrl]
    }
}

Convert-BookmarkHtmlToMarkdown @callParams @control
