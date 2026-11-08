# Changelog

Every release of the pack, newest first. Install-MtPack shows the version; Update-MtPack moves to a newer one.

## 0.1.0

- The first release: reads the ScubaResults file of ScubaGoggles 1.1.0 and reports each of its 138 Google
  Workspace policies as `MP.SCUBA.GWS.<product>.<group>.<policy>`, with the baseline's rationale, remediation and
  NIST SP 800-53 and MITRE ATT&CK mappings. Rows are tagged `SCuBA`, `SCuBA.<baseline>` and `BOD-25-01`, as in the
  ScubaGear pack, and carry the policy's MITRE ATT&CK techniques. This needs Maester 3.0.0-rc59 or later.
