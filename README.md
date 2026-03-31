# vulcan-lava

Store of years of Vulcan Lava scripts and the Perl modules related to
Maptek Vulcan Lava creation — maintained by **Brent Buffham**.

---

## What is Maptek Vulcan?

[Maptek Vulcan](https://www.maptek.com/products/vulcan/) is industry-leading
3-D mine-planning and design software.  Its built-in scripting engine,
**Lava**, is a Perl dialect that exposes the full Vulcan API.  This
repository provides:

1. **Custom Perl modules** (`lib/Vulcan/`) — a clean, object-oriented
   interface to the most-used Vulcan data types.
2. **Lava scripts** (`scripts/lava/`) — Brent Buffham's production-ready
   scripts for block-model reporting, design management, drillhole handling,
   and surface analysis.

---

## Repository Structure

```
vulcan-lava/
├── lib/
│   └── Vulcan/
│       ├── Base.pm            # Base class: project connection, error handling
│       ├── BlockModel.pm      # Block model (.bmf) reader/writer & grade-tonnage
│       ├── Design.pm          # Design database (.dgd.isis) layer/object I/O
│       ├── Drillhole.pm       # Drillhole database (.dh.isis) collar & intervals
│       ├── Triangulation.pm   # Triangulation (.00t) geometry & volume calcs
│       └── Utils.pm           # Shared utilities: coords, strings, numerics, files
│
├── scripts/
│   └── lava/
│       ├── block_models/
│       │   └── grade_tonnage_report.lava
│       ├── design/
│       │   └── list_design_objects.lava
│       ├── drillholes/
│       │   └── collar_report.lava
│       ├── triangulations/
│       │   └── surface_stats.lava
│       └── README.md
│
├── t/
│   ├── 01_base.t
│   ├── 02_block_model.t
│   ├── 03_design.t
│   ├── 04_triangulation.t
│   ├── 05_drillhole.t
│   └── 06_utils.t
│
├── cpanfile           # Perl dependency declarations
├── Makefile.PL        # ExtUtils::MakeMaker build script
└── .gitignore
```

---

## Perl Modules

### `Vulcan::Base`

Base class inherited by all other modules.  Manages project directories,
connection state, error messages, and logging.

```perl
use Vulcan::Base;
my $v = Vulcan::Base->new( project_dir => '/data/projects/mymine' );
$v->open_project() or die $v->error;
```

### `Vulcan::BlockModel`

Read/write Vulcan block-model files (`*.bmf`).  Supports field schema,
block iteration, extent filtering, and grade-tonnage calculations.

```perl
use Vulcan::BlockModel;
my $bm = Vulcan::BlockModel->new( project_dir => '/data/projects/mymine' );
$bm->open_project();
$bm->open_block_model('resource.bmf');
while ( my $block = $bm->next_block() ) { ... }
my $gt = $bm->grade_tonnage('AU_PPM', 'DENSITY', 125);
```

### `Vulcan::Design`

Layer and object management for Vulcan design databases (`*.dgd.isis`).

```perl
use Vulcan::Design;
my $dgd = Vulcan::Design->new( project_dir => $dir );
$dgd->open_project();
$dgd->open_design('pit.dgd.isis');
$dgd->create_layer('MY_LAYER');
$dgd->add_object( layer => 'MY_LAYER', name => 'obj1',
                  type => 'polygon', points => \@pts );
```

### `Vulcan::Triangulation`

Geometry operations on Vulcan triangulation files (`*.00t`): surface area,
enclosed volume, extents, and vertex/triangle management.

```perl
use Vulcan::Triangulation;
my $tri = Vulcan::Triangulation->new( project_dir => $dir );
$tri->open_triangulation('topo.00t');
printf "Area: %.2f  Volume: %.2f\n",
    $tri->calculate_area(), $tri->calculate_volume();
```

### `Vulcan::Drillhole`

Collar and downhole-interval I/O for Vulcan drillhole databases
(`*.dh.isis`), plus a straight-line desurvey utility.

```perl
use Vulcan::Drillhole;
my $dh = Vulcan::Drillhole->new( project_dir => $dir );
$dh->open_database('drillholes.dh.isis');
my $assays = $dh->get_table('DDH001', 'ASSAY');
```

### `Vulcan::Utils`

Standalone utility functions (exportable):

| Group | Functions |
|-------|-----------|
| `:coord`   | `latlon_to_utm`, `utm_to_latlon`, `dms_to_decimal`, `decimal_to_dms` |
| `:string`  | `pad_name`, `trim`, `sanitise_name` |
| `:numeric` | `round`, `clamp`, `interpolate` |
| `:file`    | `find_files`, `ensure_dir` |

---

## Getting Started

### Prerequisites

- Perl 5.10 or later
- [cpanminus](https://metacpan.org/pod/App::cpanminus) (recommended)

### Installation

```bash
git clone https://github.com/brentbuffham/vulcan-lava.git
cd vulcan-lava
cpanm --installdeps .    # install test dependencies
perl Makefile.PL
make
make test
```

### Running Tests

```bash
cd t
prove -l .
```

Or using `make`:

```bash
make test
```

### Using the Modules in Your Scripts

Add the repository `lib/` directory to Perl's search path:

```perl
use lib '/path/to/vulcan-lava/lib';
use Vulcan::BlockModel;
```

Or set the `PERL5LIB` environment variable:

```bash
export PERL5LIB=/path/to/vulcan-lava/lib:$PERL5LIB
```

---

## Running Lava Scripts

Scripts in `scripts/lava/` can be run:

**From within Vulcan:**
> Utilities → Run Lava Script → browse to the desired `.lava` file.

**From the command line** (requires Vulcan Perl libraries on `PERL5LIB`):

```bash
export PERL5LIB=/path/to/vulcan-lava/lib:$PERL5LIB
export VULCAN_PROJECT=/data/projects/mymine
export BM_FILE=resource_model.bmf
perl scripts/lava/block_models/grade_tonnage_report.lava
```

---

## Contributing

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/my-new-script`.
3. Add your script or module with tests.
4. Run `prove -l t/` and ensure all tests pass.
5. Open a pull request.

---

## Author

**Brent Buffham**

---

## Licence

This project is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
