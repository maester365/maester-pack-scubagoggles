# Unit tests of the pack, run with Pester against an installed Maester (see .github/workflows/check-pack.yml):
#   Invoke-Pester ./spec
# Set MAESTER_MODULE to a Maester.psd1 to test against a checkout of Maester instead.
Describe 'ScubaGoggles pack' {
    BeforeAll {
        $maester = if ($env:MAESTER_MODULE) { $env:MAESTER_MODULE } else { 'Maester' }
        Import-Module $maester -Force -WarningAction SilentlyContinue
        $script:PackRoot = (Resolve-Path "$PSScriptRoot/..").Path
        $script:TestsPath = Join-Path $script:PackRoot 'tests'
        # A cut of ScubaGoggles' sample report, without its raw export: rows of each result the sample has, and
        # the results it lacks (Omitted, Incorrect result, Error and a policy reported twice) written on Gmail
        # policies.
        $script:Fixture = (Resolve-Path "$PSScriptRoot/fixtures").Path
        $script:FixtureFile = Get-ChildItem -LiteralPath $script:Fixture -Filter 'ScubaResults*.json' -File -Recurse | Select-Object -First 1 -ExpandProperty FullName

        function Invoke-ScubaGogglesPack {
            param([hashtable] $Setting = @{})
            $globalSettings = @{ 'ScubaGoggles.ReportPath' = $script:Fixture; 'ScubaGoggles.MaxReportAgeDays' = 0 }
            foreach ($key in $Setting.Keys) { $globalSettings[$key] = $Setting[$key] }
            $config = [pscustomobject]@{ GlobalSettings = [pscustomobject]$globalSettings }
            @(Invoke-MtTest -Path $script:TestsPath -Id MP.SCUBA.GWS -Config $config)
        }

        $script:Rows = Invoke-ScubaGogglesPack
    }

    Context 'the pack files' {
        It 'has a valid native test' {
            $test = Get-MtTest -Path (Join-Path $script:TestsPath 'Test.MP.SCUBA.GWS.ps1')
            $test.IsValid | Should -BeTrue
            $test.Errors | Should -BeNullOrEmpty
            $test.InstanceSource | Should -Be 'Get-ScubaGwsInstance'
        }

        It 'has a catalog of unique policy IDs with their text' {
            $catalog = Get-Content (Join-Path $script:PackRoot 'catalog.json') -Raw | ConvertFrom-Json
            $catalog.Version | Should -Not -BeNullOrEmpty
            $catalog.Tests.Count | Should -BeGreaterThan 0
            @($catalog.Tests.Id | Where-Object { $_ -notmatch '^MP\.SCUBA\.GWS\.[A-Z]+\.\d+\.\d+$' }) | Should -BeNullOrEmpty
            @($catalog.Tests.Id | Sort-Object -Unique).Count | Should -Be $catalog.Tests.Count
            @($catalog.Tests | Where-Object { -not $_.Title -or -not $_.Rationale -or -not $_.Remediation -or $_.Criticality -notin 'SHALL', 'SHOULD', 'MAY' }).ControlId | Should -BeNullOrEmpty
        }
    }

    Context 'reading results' {
        It 'writes one row per result' {
            $script:Rows.Count | Should -Be 13
        }

        It 'maps <Id> to <Result>' -ForEach @(
            @{ Id = 'MP.SCUBA.GWS.ASSUREDCONTROLS.1.1'; Result = 'Passed' }      # Pass
            @{ Id = 'MP.SCUBA.GWS.CALENDAR.1.1'; Result = 'Failed' }             # Fail, a SHALL policy
            @{ Id = 'MP.SCUBA.GWS.ASSUREDCONTROLS.2.1'; Result = 'Failed' }      # Warning, a SHOULD policy
            @{ Id = 'MP.SCUBA.GWS.COMMONCONTROLS.2.1'; Result = 'Investigate' }  # No events found
            @{ Id = 'MP.SCUBA.GWS.CALENDAR.3.2'; Result = 'Skipped' }            # N/A
            @{ Id = 'MP.SCUBA.GWS.GMAIL.4.1'; Result = 'Skipped' }               # Omitted
            @{ Id = 'MP.SCUBA.GWS.GMAIL.4.2'; Result = 'Skipped' }               # Incorrect result
            @{ Id = 'MP.SCUBA.GWS.GMAIL.4.3'; Result = 'Error' }                 # Error
            @{ Id = 'MP.SCUBA.GWS.GMAIL.4.4'; Result = 'Error' }                 # Error - Test results missing
            @{ Id = 'MP.SCUBA.GWS.GMAIL.4.4-2'; Result = 'Passed' }              # the same policy reported again
        ) {
            ($script:Rows | Where-Object Id -eq $Id).Result | Should -Be $Result
        }

        It 'rates a SHALL policy High and a SHOULD policy Medium' {
            ($script:Rows | Where-Object Id -eq 'MP.SCUBA.GWS.CALENDAR.1.1').Severity | Should -Be 'High'
            ($script:Rows | Where-Object Id -eq 'MP.SCUBA.GWS.ASSUREDCONTROLS.2.1').Severity | Should -Be 'Medium'
        }

        It 'tags each row with its baseline and gives it the policy''s ATT&CK techniques' {
            $row = $script:Rows | Where-Object Id -eq 'MP.SCUBA.GWS.ASSUREDCONTROLS.2.1'
            $row.Tag | Should -Contain 'SCuBA'
            $row.Tag | Should -Contain 'SCuBA.ASSUREDCONTROLS'
            @($row.Mitre).Count | Should -BeGreaterThan 0
            ($script:Rows | Where-Object Id -eq 'MP.SCUBA.GWS.CALENDAR.1.1').Tag | Should -Contain 'BOD-25-01'
        }

        It 'describes the policy from the catalog and shows the details as Markdown' {
            $row = $script:Rows | Where-Object Id -eq 'MP.SCUBA.GWS.ASSUREDCONTROLS.2.1'
            $row.Title | Should -Be 'Data processing across multiple regions SHOULD be disabled for all Google Workspace products.'
            $row.ResultDetail.TestDescription | Should -BeLike '`*`*GWS.ASSUREDCONTROLS.2.1v1`*`* (SHOULD)*'
            $row.ResultDetail.TestDescription | Should -BeLike '*#### Remediation*'
            $row.ResultDetail.TestResult | Should -BeLike '*- `*`*Cool Example Org`*`*: *'
            @($script:Rows.ResultDetail.TestResult) -match '<[a-z]' | Should -BeNullOrEmpty
        }

        It 'keeps the reasons ScubaGoggles gives for what it does not check' {
            ($script:Rows | Where-Object Id -eq 'MP.SCUBA.GWS.CALENDAR.3.2').ReasonDetail | Should -BeLike '*manually check*'
            ($script:Rows | Where-Object Id -eq 'MP.SCUBA.GWS.GMAIL.4.1').ReasonDetail | Should -BeLike 'Omitted in the ScubaGoggles config.*another team*'
            ($script:Rows | Where-Object Id -eq 'MP.SCUBA.GWS.GMAIL.4.2').ReasonDetail | Should -BeLike '*ScubaGoggles reported Fail*'
        }

        It 'reads the results from the file, its run folder or the output folder' {
            (Invoke-ScubaGogglesPack -Setting @{ 'ScubaGoggles.ReportPath' = $script:FixtureFile }).Count | Should -Be 13
            (Invoke-ScubaGogglesPack -Setting @{ 'ScubaGoggles.ReportPath' = (Split-Path -Parent $script:FixtureFile) }).Count | Should -Be 13
        }
    }

    Context 'skipping the pack' {
        It 'skips the family when no results are set' {
            $rows = Invoke-ScubaGogglesPack -Setting @{ 'ScubaGoggles.ReportPath' = '' }
            $rows.Count | Should -Be 1
            $rows[0].Result | Should -Be 'Skipped'
            $rows[0].ReasonDetail | Should -BeLike '*Run scubagoggles gws*'
        }

        It 'skips the family when the results are missing' {
            $rows = Invoke-ScubaGogglesPack -Setting @{ 'ScubaGoggles.ReportPath' = (Join-Path $TestDrive 'none') }
            $rows.Count | Should -Be 1
            $rows[0].ReasonDetail | Should -BeLike '*No ScubaGoggles results file was found*'
        }

        It 'skips the family when the results are too old' {
            $rows = Invoke-ScubaGogglesPack -Setting @{ 'ScubaGoggles.MaxReportAgeDays' = 7 }
            $rows.Count | Should -Be 1
            $rows[0].ReasonDetail | Should -BeLike '*written on 2026-10-15, more than 7 days ago*'
        }

        It 'skips the family for results another SCuBA tool wrote' {
            $report = Get-Content -LiteralPath $script:FixtureFile -Raw | ConvertFrom-Json
            $report.MetaData.Tool = 'ScubaGear'
            $file = Join-Path $TestDrive 'ScubaResults_gear.json'
            $report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $file -Encoding utf8
            $rows = Invoke-ScubaGogglesPack -Setting @{ 'ScubaGoggles.ReportPath' = $file }
            $rows.Count | Should -Be 1
            $rows[0].ReasonDetail | Should -BeLike '*written by ScubaGear, not ScubaGoggles*'
        }
    }
}
