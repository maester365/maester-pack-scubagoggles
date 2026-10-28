# CISA ScubaGoggles pack for Maester

A [Maester Pack](https://maester.dev/docs/next/packs) that shows the results of
[ScubaGoggles](https://github.com/cisagov/ScubaGoggles) in the Maester report. ScubaGoggles is CISA's free tool
that checks a Google Workspace tenant against the Secure Cloud Business Applications (SCuBA) baselines for Google
Workspace: Gmail, Drive and Docs, Common Controls, Calendar, Chat, Meet, Groups, Sites, Classroom, Gemini and
Assured Controls.

Each policy is one row, `MP.SCUBA.GWS.<product>.<group>.<policy>`: `GWS.GMAIL.1.1v1` is `MP.SCUBA.GWS.GMAIL.1.1`.
The ID leaves out the policy's version, so a row keeps its ID when CISA updates the policy. Each row has the
policy's requirement as its title, the baseline's rationale, the steps to configure it, its NIST SP 800-53 and
MITRE ATT&CK mappings, and what ScubaGoggles found. Rows are tagged `ScubaGoggles` and `GWS.<product>`
(`GWS.GMAIL`, `GWS.DRIVEDOCS` and so on), and policies that BOD 25-01 requires are tagged `BOD-25-01`.

The pack does not sign in to Google or run ScubaGoggles: you run ScubaGoggles, and the pack reads the results file
it wrote. It needs Maester 3.0 or later.

## Run it

Install ScubaGoggles once, with Python 3.11 or later:

```bash
pip install scubagoggles
scubagoggles setup
```

`scubagoggles setup` downloads [Open Policy Agent](https://www.openpolicyagent.org/), which ScubaGoggles uses to
evaluate the policies, and saves the output folder and the credentials file. ScubaGoggles signs in with a Google
OAuth client and a super admin, or with a service account that has domain-wide delegation; its
[authentication guide](https://github.com/cisagov/ScubaGoggles/blob/main/docs/authentication/AuthenticationMethods.md)
says how to set up either one.

Run the assessment:

```bash
scubagoggles gws -o ./scubagoggles
```

Install the pack, point it at the output folder in `maester-config.json`, and run it:

```powershell
Install-MtPack maester365/maester-pack-scubagoggles
```

```json
{ "GlobalSettings": { "ScubaGoggles.ReportPath": "./scubagoggles" } }
```

```powershell
Invoke-Maester -Pack SCUBA.GWS -SkipBuiltIn -SkipGraphConnect    # only the ScubaGoggles results
Invoke-Maester                                                   # Maester's tests and the ScubaGoggles results
```

`Install-MtPack` shows what the pack can reach (no services, no network, no modules: it only reads a file) and
asks you to approve it. It records the pack in `maester-packs.lock.json` and in the `Packs` list of
`maester-config.json`. Once installed, the pack runs with every `Invoke-Maester`; without `ScubaGoggles.ReportPath`
it reports one skipped row that says what to do.

`ScubaGoggles.ReportPath` takes the `ScubaResults_<uuid>.json` file, the `GWSBaselineConformance_<time>` folder
that one run wrote it in, or the output folder, where the pack reads the newest run. It refuses a report older
than `ScubaGoggles.MaxReportAgeDays` (7 by default; 0 turns the check off), and a results file that another SCuBA
tool, such as ScubaGear, wrote.

Maester does not connect to Google for this pack. `Connect-Maester` is only needed for the other tests you run with
it: when you run the pack on its own, add `-SkipGraphConnect`, or `Invoke-Maester` stops because it is not
connected to Microsoft Graph.

## Run it in a pipeline

Run ScubaGoggles with a service account as its own step, then Maester in the same job:

```yaml
- name: Run ScubaGoggles
  run: |
    pip install scubagoggles
    mkdir -p ~/opa
    # Saves the paths and downloads OPA into ~/opa.
    scubagoggles setup --opapath ~/opa --credentials ./service-account.json --outputpath ./scubagoggles
    scubagoggles gws --subjectemail admin@example.org --quiet

- name: Run Maester
  shell: pwsh
  run: |
    Install-Module Maester -Scope CurrentUser -Force
    Restore-MtPack
    Invoke-Maester -Pack SCUBA.GWS -SkipBuiltIn -SkipGraphConnect -NonInteractive -OutputFolder ./test-results
```

Install the pack once on your own computer and commit `maester-packs.lock.json` and `maester-config.json`:
`Restore-MtPack` installs the same files in the pipeline. Keep the service account key in a pipeline secret, and
write it to `service-account.json` in an earlier step. See
the ScubaGoggles [parameters](https://github.com/cisagov/ScubaGoggles/blob/main/docs/usage/Parameters.md) for
`--subjectemail` and the other options.

## Settings

All settings go in `GlobalSettings` of `maester-config.json`.

| Setting | Default | What it does |
| --- | --- | --- |
| `ScubaGoggles.ReportPath` | empty | The ScubaResults file, the folder one run wrote it in, or the output folder (the newest run is read). |
| `ScubaGoggles.MaxReportAgeDays` | `7` | Refuse a report older than this. `0` turns the check off. |

## How results map

| ScubaGoggles result | Maester result |
| --- | --- |
| Pass | Passed |
| Fail (a SHALL policy) | Failed, High severity |
| Warning (a SHOULD or MAY policy) | Failed, Medium or Low severity |
| No events found | Investigate: a log-based check found no event that shows the setting |
| N/A | Skipped: ScubaGoggles doesn't check the policy, so check it by hand |
| Omitted | Skipped, with the reason from your ScubaGoggles config |
| Incorrect result | Skipped, with what ScubaGoggles reported |
| Error | Error |

The severity follows the policy's criticality whatever the result: SHALL is High, SHOULD is Medium, MAY is Low.

ScubaGoggles writes its own HTML report, `BaselineReports.html`, beside the results file. It is several files, so
the Maester report links to the baselines rather than embedding it; open it from the ScubaGoggles output folder.

## Report an issue

CISA writes and maintains the baselines and ScubaGoggles' checks. If a result, the text of a policy or its steps
look wrong, raise it in [cisagov/ScubaGoggles](https://github.com/cisagov/ScubaGoggles/issues). Problems with
reading the results in Maester go to [this repository's issues](https://github.com/maester365/maester-pack-scubagoggles/issues).

## Maintaining the pack

`catalog.json` lists the policies of CISA's Google Workspace baselines, with their text, mappings and steps, for
the pack's page on the pack index and for each result's description. It is generated; do not edit it. To move the
pack to a new version of ScubaGoggles, clone that release and run the generator:

```powershell
git clone --depth 1 --branch v1.1.0 https://github.com/cisagov/ScubaGoggles ~/src/ScubaGoggles
. ./tools/Update-ScubaGwsCatalog.ps1
Update-ScubaGwsCatalog -SourcePath ~/src/ScubaGoggles
```

The generator reads the baseline Markdown (`scubagoggles/baselines/*.md`), so a change to how CISA writes those
files can drop a field. The pack check ([check-pack.yml](.github/workflows/check-pack.yml)) fails when a policy has
no title, criticality, rationale or remediation. It also runs the pack on `tools/fixtures`, a cut of ScubaGoggles'
sample report with each result ScubaGoggles writes, and fails when one maps to the wrong Maester result. When
ScubaGoggles changes the results it writes (a new `Result` value, say; CISA documents the file in
[tooloutputschema.md](https://github.com/cisagov/ScubaGoggles/blob/main/docs/misc/tooloutputschema.md)), update
`Test-ScubaGws` in [tests/Test.MP.SCUBA.GWS.ps1](tests/Test.MP.SCUBA.GWS.ps1), the fixture and the check.

Releases work as in the [demo pack](https://github.com/maester365/maester-pack-demo#versions-and-releases): with
the repository variable `PACK_RELEASES` set to `true`, every merged pull request gets the next version and a
release, with its notes from [CHANGELOG.md](CHANGELOG.md). Without it, `Install-MtPack` installs `main`.

## Files

| Path | What it is |
| --- | --- |
| `maester-pack.json` | The manifest: ID, code, version, the suite, helpers and catalog |
| `maester-pack.guide.json` | How to install and run the pack, for its page on the pack index |
| `catalog.json` | The baselines' policies, generated by `tools/Update-ScubaGwsCatalog.ps1` |
| `tests/` | The suite: the `MP.SCUBA.GWS` family test, with its instance source, and its Markdown |
| `helpers/` | Finding and reading the results file, the catalog, and turning ScubaGoggles' HTML into Markdown |
| `tools/` | The catalog generator and the fixture the pack check runs on. The pack never loads it |

## Licence

This pack is published under the [MIT licence](LICENSE). ScubaGoggles and the SCuBA baselines are published by CISA
under [CC0 1.0](https://github.com/cisagov/ScubaGoggles/blob/main/LICENSE); the pack does not include ScubaGoggles'
code. `catalog.json` is generated from the baselines, and `tools/fixtures` is cut from ScubaGoggles' sample report.
CISA does not endorse this pack.
