function Get-ScubaGwsInstance {
    <#
    .SYNOPSIS
    Returns one MP.SCUBA.GWS instance per policy result in a ScubaGoggles ScubaResults file.

    .DESCRIPTION
    Instance source of the MP.SCUBA.GWS family. Reads the ScubaResults JSON that the scubagoggles gws command wrote,
    from the ScubaGoggles.ReportPath setting, and returns one instance per result. Skips the whole family, with
    the reason, when the setting is empty, the file is not found or the report is too old.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $reportPath = [string](Get-MtSetting -Name 'ScubaGoggles.ReportPath' -Default '')
    if ([string]::IsNullOrWhiteSpace($reportPath)) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'No ScubaGoggles report to read. Run scubagoggles gws, then set the ScubaGoggles.ReportPath setting to the ScubaResults file or the folder it wrote.'
    }

    $file = Resolve-ScubaGwsResultFile -Path $reportPath
    $report = Get-Content -LiteralPath $file -Raw -Encoding utf8 | ConvertFrom-Json -Depth 20
    if (-not $report.PSObject.Properties['Results'] -or -not $report.PSObject.Properties['MetaData']) {
        throw "$file is not a ScubaGoggles results file: it has no MetaData or Results."
    }
    if ([string]$report.MetaData.Tool -ne 'ScubaGoggles') {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "$file was written by $($report.MetaData.Tool), not ScubaGoggles."
    }

    $maxAgeDays = [int](Get-MtSetting -Name 'ScubaGoggles.MaxReportAgeDays' -Default 7)
    # ConvertFrom-Json reads the ISO date as a DateTime already; text is parsed invariantly, never in the current culture.
    $written = [datetime]::MinValue
    $hasDate = if ($report.MetaData.TimestampZulu -is [datetime]) { $written = $report.MetaData.TimestampZulu; $true }
    else {
        [datetime]::TryParse([string]$report.MetaData.TimestampZulu, [cultureinfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$written)
    }
    if ($maxAgeDays -gt 0 -and $hasDate -and $written.ToUniversalTime() -lt [datetime]::UtcNow.AddDays(-$maxAgeDays)) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "The ScubaGoggles report at $file was written on $($written.ToString('yyyy-MM-dd')), more than $maxAgeDays days ago. Run scubagoggles gws again, or raise the ScubaGoggles.MaxReportAgeDays setting."
    }

    ConvertTo-ScubaGwsInstance -Report $report -Catalog (Get-ScubaGwsCatalog)
}

function Test-ScubaGws {
    [MaesterTest(
        Id = 'MP.SCUBA.GWS',
        Title = 'CISA ScubaGoggles for Google Workspace',
        Product = 'Google Workspace',
        InstanceSource = 'Get-ScubaGwsInstance',
        Tag = 'ScubaGoggles',
        Author = 'merill',
        HelpUrl = 'https://github.com/maester365/maester-pack-scubagoggles'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # One result of a ScubaGoggles report, supplied by the engine.
        $Instance
    )

    $row = $Instance.Data.Row
    $description = Get-ScubaGwsDescription -ControlId ([string]$row.'Control ID') -Criticality ([string]$row.Criticality) `
        -Product $(if ($Instance.Data.Policy) { [string]$Instance.Data.Policy.Product } else { [string]$Instance.Data.Product }) `
        -Group $Instance.Data.Group -Policy $Instance.Data.Policy
    $details = ConvertFrom-ScubaGwsHtml -Html ([string]$row.Details)
    $detail = @{ Description = $description; Result = $details }

    switch -Regex ([string]$row.Result) {
        '^Pass$' {
            Add-MtTestResultDetail @detail
            return $true
        }
        '^(Fail|Warning)$' {
            # Warning is a SHOULD or MAY policy that is not met; the instance's severity says how much it matters.
            Add-MtTestResultDetail @detail
            return $false
        }
        '^No events found$' {
            # A log-based check found no event that shows the setting, so its state is unknown.
            Add-MtTestResultDetail @detail -Investigate
            return $true
        }
        '^N/A$' {
            $reason = if ($details) { $details } else { 'ScubaGoggles cannot check this policy automatically. Check it by hand.' }
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason $reason
        }
        '^Omitted$' {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "Omitted in the ScubaGoggles config. $details".Trim()
        }
        '^Incorrect result$' {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "Marked as an incorrect result in the ScubaGoggles config. ScubaGoggles reported $($row.OriginalResult). $details".Trim()
        }
        default {
            # Error, Error - Test results missing, or a result this version of the pack does not know.
            Add-MtTestResultDetail @detail -SkippedBecause Error
        }
    }
}
