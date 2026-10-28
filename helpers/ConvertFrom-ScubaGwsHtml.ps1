function ConvertFrom-ScubaGwsHtml {
    <#
    .SYNOPSIS
    Turns the HTML that ScubaGoggles writes in a result's Requirement and Details into Markdown.

    .DESCRIPTION
    ScubaGoggles writes its details for its own HTML report: definition lists of organisational units, line
    breaks, lists and links. They become Markdown, and every other tag is removed, so nothing from the report is
    shown as HTML in the Maester report. The indicator badges after a requirement are left out.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()] [AllowEmptyString()] [string] $Html
    )

    if ([string]::IsNullOrWhiteSpace($Html)) { return '' }
    $text = $Html -replace '(?s)<div class="badges">.*?</div>', ''
    $text = $text -replace '(?is)<a\s[^>]*href="(https?://[^"]+)"[^>]*>(.*?)</a>', '[$2]($1)'
    $text = $text -replace '(?is)<dt>(.*?)</dt>\s*<dd>(.*?)</dd>', '**$1**: $2'
    $text = $text -replace '(?i)<br\s*/?>', "`n"
    $text = $text -replace '(?i)<li[^>]*>', "`n- "
    $text = $text -replace '(?i)</?(b|strong)>', '**'
    $text = $text -replace '(?i)</?(i|em)>', '_'
    $text = $text -replace '<[^>]+>', ''
    $text = [System.Net.WebUtility]::HtmlDecode($text)
    # A list item that ScubaGoggles starts on its own line ("- " then the text on the next) is one line.
    $text = $text -replace '(?m)^(\s*)-\s*\n\s+', '$1- '
    $text = $text -replace '(?m)[ \t]+$', ''
    ($text -replace '\n{3,}', "`n`n").Trim()
}
