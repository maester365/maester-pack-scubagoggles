Reports each result of [CISA ScubaGoggles](https://github.com/cisagov/ScubaGoggles), which checks a Google
Workspace tenant against CISA's Secure Cloud Business Applications (SCuBA) baselines for Google Workspace.

Each policy is its own row, `MP.SCUBA.GWS.<product>.<group>.<policy>` (for example `MP.SCUBA.GWS.GMAIL.1.1` for
`GWS.GMAIL.1.1v1`), with the baseline's rationale, the steps to configure it and what ScubaGoggles found.

#### Running it

Run `scubagoggles gws`, set the `ScubaGoggles.ReportPath` setting to the results it wrote, then run
results it wrote, then run `Invoke-Maester -Pack SCUBA.GWS`.

<!--- Results --->
%TestResult%
