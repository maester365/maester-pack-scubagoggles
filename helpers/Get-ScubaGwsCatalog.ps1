function Get-ScubaGwsCatalog {
    <#
    .SYNOPSIS
    Returns the pack's catalog of ScubaGoggles policies, by control ID without its version (GWS.GMAIL.1.1).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $catalog = @{}
    $path = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'catalog.json'
    if (Test-Path -LiteralPath $path) {
        foreach ($entry in @((Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json).Tests)) {
            $catalog[([string]$entry.ControlId -replace 'v\d+$', '')] = $entry
        }
    }
    $catalog
}
