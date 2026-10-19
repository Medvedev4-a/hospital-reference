# GitHub distribution

The repository contains the PostgreSQL/PostGIS schema, synthetic data generator,
integrity checks, access-control policies, documentation and verified reports.
All patient data is synthetic. No database passwords are included.

The full database archive (`hospital_reference.backup`) and original complete
project ZIP are distributed as release assets, outside Git history.
Download the backup into this directory before running `restore.ps1`.
See `README.md` for prerequisites and deployment instructions.

`MANIFEST.json` records the original verified delivery package. It includes
release-only backup and workflow-log files, and does not describe subsequent
GitHub packaging changes. Verification reports describe the tested local
reference deployment, not an automated GitHub CI run.
