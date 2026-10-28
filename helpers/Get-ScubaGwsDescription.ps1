function Get-ScubaGwsDescription {
    <#
    .SYNOPSIS
    Writes the Markdown description of one policy: its rationale, note, how to configure it and its mappings.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $ControlId,
        [Parameter()] [string] $Criticality,
        [Parameter()] [string] $Product,
        [Parameter()] $Group,
        [Parameter()] $Policy
    )

    $groupName = if ($Policy) { [string]$Policy.Group } elseif ($Group) { [string]$Group.GroupName } else { '' }
    $where = @($Product, $groupName) | Where-Object { $_ }
    $lines = [System.Collections.Generic.List[string]]::new()
    # ScubaGoggles writes Shall/Not-Implemented or Should/3rd Party for a policy it does not check itself.
    $level = ($Criticality -split '/')[0].Trim().ToUpperInvariant()
    $lines.Add("**$ControlId** ($level) · $($where -join ' › ')")
    if ($Policy -and $Policy.Rationale) { $lines.Add(''); $lines.Add([string]$Policy.Rationale) }
    if ($Policy -and $Policy.Note) { $lines.Add(''); $lines.Add("_Note:_ $($Policy.Note)") }
    if ($Policy -and $Policy.Remediation) {
        $lines.Add(''); $lines.Add('#### Remediation'); $lines.Add(''); $lines.Add([string]$Policy.Remediation)
    }
    $links = [System.Collections.Generic.List[string]]::new()
    $url = if ($Policy -and $Policy.Url) { [string]$Policy.Url } elseif ($Group -and $Group.GroupReferenceURL) { [string]$Group.GroupReferenceURL } else { $null }
    if ($url) { $links.Add("[CISA baseline]($url)") }
    if ($Policy -and @($Policy.Nist).Count) { $links.Add("NIST SP 800-53: $(@($Policy.Nist) -join ', ')") }
    if ($Policy -and @($Policy.Mitre).Count) { $links.Add("MITRE ATT&CK: $(@($Policy.Mitre) -join ', ')") }
    if ($links.Count) { $lines.Add(''); $lines.Add($links -join ' · ') }
    $lines -join "`n"
}
