function Resolve-ScubaGwsResultFile {
    <#
    .SYNOPSIS
    Returns the ScubaResults file at Path: the file itself, the newest in the folder, or the newest in a folder in it.

    .DESCRIPTION
    scubagoggles gws writes ScubaResults_<uuid>.json in a new GWSBaselineConformance_<time> folder under its output
    path on every run, so Path can be the file, that run's folder, or the output path, where the newest run wins.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) { return (Resolve-Path -LiteralPath $Path).ProviderPath }
    $file = $null
    if (Test-Path -LiteralPath $Path -PathType Container) {
        $file = @(Get-ChildItem -LiteralPath $Path -Filter 'ScubaResults*.json' -File) | Sort-Object -Property LastWriteTimeUtc -Descending | Select-Object -First 1
        if (-not $file) {
            $file = @(Get-ChildItem -LiteralPath $Path -Directory | ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Filter 'ScubaResults*.json' -File }) |
                Sort-Object -Property LastWriteTimeUtc -Descending | Select-Object -First 1
        }
    }
    if (-not $file) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "No ScubaGoggles results file was found at $Path. Point the ScubaGoggles.ReportPath setting at a ScubaResults_<uuid>.json file, the folder scubagoggles gws wrote it in, or its output folder."
    }
    $file.FullName
}
