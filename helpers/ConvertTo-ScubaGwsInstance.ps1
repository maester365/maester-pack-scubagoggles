function ConvertTo-ScubaGwsInstance {
    <#
    .SYNOPSIS
    Turns the Results of a ScubaGoggles report into MP.SCUBA.GWS instances.

    .DESCRIPTION
    The instance suffix is the control ID without GWS. and its version (GMAIL.1.1 for GWS.GMAIL.1.1v1), so a row
    keeps its ID when CISA moves a policy to a new version. A control that ScubaGoggles reports more than once gets
    -2, -3 and so on, in report order. Each instance carries the report's row, its group and the policy's catalog
    entry, and the severity of its criticality: SHALL is High, SHOULD Medium and MAY Low.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # A ScubaGoggles report, read from its ScubaResults JSON.
        [Parameter(Mandatory)] $Report,

        # The pack's catalog, from Get-ScubaGwsCatalog.
        [Parameter()] [hashtable] $Catalog = @{}
    )

    $severity = @{ shall = 'High'; should = 'Medium'; may = 'Low' }
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($product in $Report.Results.PSObject.Properties) {
        foreach ($group in @($product.Value)) {
            foreach ($row in @($group.Controls)) {
                $controlId = [string]$row.'Control ID'
                $policy = $controlId -replace 'v\d+$', ''
                $id = ($policy -replace '^GWS\.', '' -replace '[^A-Za-z0-9._-]', '_') -replace '^[^A-Za-z0-9]+', ''
                if (-not $id) { continue }
                $unique = $id
                for ($n = 2; -not $seen.Add($unique); $n++) { $unique = "$id-$n" }
                $entry = $Catalog[$policy]
                $title = if ($entry) { [string]$entry.Title } else { ConvertFrom-ScubaGwsHtml -Html ([string]$row.Requirement) }
                $tags = @('ScubaGoggles', ($policy -replace '\.\d+\.\d+$', ''))
                if ($entry -and @($entry.Indicators) -contains 'BOD 25-01 Requirement') { $tags += 'BOD-25-01' }
                $instance = [ordered]@{
                    Id    = $unique
                    Title = ($title -replace '\s+', ' ').Trim()
                    Tag   = $tags
                    Data  = [pscustomobject]@{ Row = $row; Group = $group; Policy = $entry; Product = $product.Name }
                }
                $level = ([string]$row.Criticality -split '/')[0].Trim().ToLowerInvariant()
                if ($severity.ContainsKey($level)) { $instance.Severity = $severity[$level] }
                [pscustomobject]$instance
            }
        }
    }
}
