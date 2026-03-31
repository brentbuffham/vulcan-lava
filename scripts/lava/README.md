# Lava Scripts

This directory contains Brent Buffham's collection of Lava scripts for
Maptek Vulcan.

## What is Lava?

**Lava** is the built-in Perl-based scripting language embedded in
Maptek Vulcan.  Lava scripts automate repetitive mine-planning tasks
by calling Vulcan's internal API through Perl.

Scripts in this directory typically have a `.lava` extension and are
run from within the Vulcan environment via
**Utilities → Run Lava Script**.

## Directory Layout

```
scripts/lava/
├── block_models/        Block model reporting and filtering scripts
├── design/              Design file creation and manipulation scripts
├── drillholes/          Drillhole import, validation, and reporting
├── triangulations/      Surface and solid triangulation utilities
└── reporting/           General mine-planning reports
```

## Running a Script

1. Open Maptek Vulcan and load your project.
2. From the menu choose **Utilities → Run Lava Script**.
3. Browse to the desired `.lava` file in this directory.
4. Fill in any prompted parameters and click **OK**.

Alternatively, scripts can be run from the command line (outside Vulcan)
using the system Perl interpreter when the Vulcan libraries are on
`PERL5LIB`:

```bash
export PERL5LIB=/path/to/vulcan/perl/lib:./lib
perl scripts/lava/block_models/grade_tonnage_report.lava
```

## Script Conventions

| Convention | Detail |
|---|---|
| Encoding | UTF-8 |
| Line endings | Unix (LF) |
| Shebang | `#!/usr/bin/perl` or omitted for Vulcan Lava execution |
| `use strict` | Always |
| `use warnings` | Always |
| Error handling | `die` / `warn` with descriptive messages |
| Output | `print` to STDOUT; Vulcan captures this in the log window |

## Adding New Scripts

1. Place the script in the appropriate sub-directory (create one if needed).
2. Add a short header comment block describing purpose, inputs, and outputs.
3. Test the script against a representative project before committing.

## Author

Brent Buffham
