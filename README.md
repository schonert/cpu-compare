# CPU compare

Compare up to four processors side by side on public benchmark data. Rails 8,
ViewComponent, Tailwind CSS 4 and SQLite.

Two rules shape everything here: **every number traces back to a named
measurement protocol**, and **the whole dataset is legally redistributable**.

## Where the data comes from

| Source | Licence | Used for |
| --- | --- | --- |
| [Blender Open Data][bod] | CC0 1.0 | Every benchmark figure |
| Reported by machines | CC0 1.0 | Cores and threads, read back out of the runs |
| [Wikidata][wd] | CC0 1.0 | Specifications |
| Intel ARK, AMD product pages | Vendor terms | Specifications (no importer yet — see below) |

The Blender snapshot ships its own `LICENSE.txt`, and the importer **verifies it
is CC0 before writing a row** — if upstream ever changes the licence, ingest
stops rather than quietly republishing something we may not.

Deliberately **not** ingested: PassMark, Geekbench Browser, notebookcheck,
CPU-Monkey, TechPowerUp, UserBenchmark. Their terms do not permit
redistribution. PassMark is registered in `sources` as licensed and
non-redistributable so the constraint is enforced in data rather than left to
memory; if a paid CSV is ever licensed it goes into
`licensed_benchmark_results`, flagged, and is never aggregated into a score.

[bod]: https://opendata.blender.org/
[wd]: https://www.wikidata.org/

## Scoring

One score per **(cpu, benchmark, benchmark version, workload)**. There is no
blended headline number anywhere, and no table it could be stored in.

- **Median, not mean.** Open Data is a public firehose: the same chip shows up
  throttled, virtualised and background-loaded. On the Ryzen 9 5950X / Monster
  group the minimum is 16 samples/min against a median near 200 — a mean would
  track the junk.
- **Sample count, IQR and dates are stored with every score** and shown with
  every figure.
- **Scores under 5 samples are suppressed**, not deleted. The threshold is
  `aggregation.min_samples` in `config/scoring.yml`; the score keeps the
  threshold that was in force when it was computed.
- **Major versions are never mixed.** Blender 4.x and 5.x are separate series,
  and 2.x is separate again — it predates the samples-per-minute metric
  entirely and is measured in seconds, where lower is better.
- **No composite is defined.** If one is ever added it must be declared in
  `config/scoring.yml`, which is rendered publicly at `/methodology`; a
  composite whose weights do not sum to 1, or which spans benchmark versions,
  raises rather than producing a number nobody can account for.

### What the snapshot actually contains

From the 2026-09-14 snapshot (429,492 upstream submissions, 1.9 GB of JSONL):

| | |
| --- | --- |
| CPU scene-results stored | 665,661 |
| Aggregated into scores | 650,036 |
| Excluded: multi-socket | 11,467 |
| Excluded: thread-restricted | 2,285 |
| Excluded: unidentifiable processor | 1,873 |
| Distinct processors | 2,320 |
| Scores computed | 16,692 |
| Published (≥ 5 samples) | 7,807 |

Excluded measurements keep their row and their reason, so a sample count can
always be reconciled against the raw data — the measurements page prints the
exclusions next to the figure.

## The presentation contract

Every displayed number shows its **value with units, sample count, source,
benchmark version and date**, and links to the measurements behind it. That is
enforced by construction: benchmark figures render through `FigureComponent` /
`FigureMetaComponent`, which cannot render a value without its provenance.
`/measurements/:id` lists every individual run — date, value, build, cores,
threads, OS, and the raw device string the machine reported — so a
mis-normalised name is visible rather than hidden behind the canonical one.

Workloads are shown **side by side**, never collapsed into one rank. A chip can
lead on Monster and trail on Classroom, and that is information.

## Getting started

```bash
bin/setup
```

That installs dependencies and prepares the database with the source, benchmark
and workload vocabulary — but no measurements, since the snapshot is ~100 MB and
is not checked in. Then:

```bash
bin/rails ingest:all
```

which downloads the snapshot, ingests it, pulls specifications from Wikidata and
computes every score. It takes a few minutes; the ingest itself is about two
minutes for 665,000 measurements. `bin/setup --with-data` does both at once.

```bash
bin/dev
```

### Ingest tasks

```bash
bin/rails ingest:snapshot   # download the snapshot, print its checksum and licence
bin/rails ingest:blender    # ingest measurements (idempotent)
bin/rails ingest:reported_specs  # read cores and threads back out of the stored runs
bin/rails ingest:wikidata   # attach specifications to processors already in the catalogue
bin/rails ingest:score      # recompute every score from the stored submissions
bin/rails ingest:status     # what is and is not resolved
```

**Ingest is idempotent and re-runnable against a new snapshot without losing
history.** Every measurement is keyed on the `(upstream_id, entry_index)` that
Open Data assigns and never reuses, so a re-run updates what is there and
inserts only what is new. Nothing is deleted: a measurement that drops out of a
later snapshot keeps its row and its `last_seen_run`. Each run is recorded in
`ingest_runs` with the snapshot's name, checksum and counts.

## How it is put together

```
app/models/
  source.rb                 where a fact came from, and whether we may republish it
  benchmark_suite.rb        a named measurement protocol
  benchmark_version.rb      one major series — the unit within which results compare
  workload.rb               one scene, scored on its own
  cpu.rb                    a processor; spec columns materialised from cpu_specs
  cpu_alias.rb              every raw device string seen, and what it resolved to
  cpu_spec.rb               one sourced fact, with a deep link to the statement
  benchmark_submission.rb   the raw measurements — the evidence layer
  benchmark_score.rb        one aggregate per (cpu, version, workload, metric)
  ingest_run.rb             provenance for every ingest and scoring pass
  licensed_benchmark_result.rb   isolated; never aggregated
  openbenchmarking_result.rb     isolated; never aggregated

app/services/
  blender_open_data/snapshot.rb   streams the zip; verifies the licence
  blender_open_data/entry.rb      flattens schema v1–v4 into one shape
  blender_open_data/catalog.rb    the source/version/workload vocabulary
  blender_open_data/importer.rb   idempotent upsert into submissions
  cpus/name_normalizer.rb         raw OS strings → canonical processor names
  cpus/resolver.rb                alias table, with manual overrides preserved
  cpus/spec_writer.rb             writes a sourced fact, then materialises it
  cpus/reported_specs.rb          cores and threads as the mode of what machines reported
  scoring/config.rb               reads config/scoring.yml
  scoring/quantiles.rb            linear-interpolation quantiles
  scoring/aggregator.rb           median, IQR, suppression
  wikidata/spec_importer.rb       specifications for processors we already hold
```

### Normalising device names

Open Data records whatever the machine called itself, so one chip arrives in
many spellings — 2,846 distinct strings fold onto 2,320 processors:

```
AMD Ryzen 9 5950X 16-Core Processor          → AMD Ryzen 9 5950X
12th Gen Intel Core i7-12700K                → Intel Core i7-12700K
Intel(R) Xeon(R) CPU        W3680  @ 3.33GHz → Intel Xeon W3680
AMD Ryzen 5 PRO 2400G with Radeon Vega Graphics → AMD Ryzen 5 PRO 2400G
INTEL XEON PLATINUM 8568Y+                   → Intel Xeon Platinum 8568Y+
```

Anything that identifies no specific part is **rejected with a reason** rather
than guessed at, because a wrong match silently pools two chips' samples into
one median: engineering samples, virtualised CPUs, masked model numbers, and
names with no model number at all (`Genuine Intel CPU @ 2.20GHz` would otherwise
collapse onto a bare "Intel"). That is 0.37% of submissions. Unmatched strings
are kept in `cpu_aliases` with a null `cpu_id`, so coverage is a number you can
query. Setting `cpu_id` by hand and marking the row `manual` fixes a mismatch,
and ingest will not overwrite it.

### Where specifications come from

Wikidata is thin: its "CPU model" class holds 284 entities, of which 124 carry
core counts and almost none carry clocks, TDP or launch price — against 2,320
processors in the benchmark feed. On its own it filled in cores for 6% of the
comparable catalogue and threads for 4%.

So cores and threads are instead **read back out of the benchmark runs**. Every
Blender submission records the machine it ran on, which covers 2,158
processors. The figure is the **mode** — the most commonly reported value — for
the same reason scores use the median: a public feed is full of VMs and
restricted containers that under-report. The Ryzen 9 5950X is reported as 16
cores 28,563 times and as 8 cores 238 times.

| | Wikidata only | With machine-reported |
| --- | --- | --- |
| Cores | 6.1% | **96.8%** |
| Threads | 4.4% | **97.5%** |

These are measured figures, not vendor statements, and the site says so: each
cell cites its source and, for a measured one, how many runs it came from and
how far they agreed. A processor whose machines agree less than 75% of the time
publishes nothing rather than picking a winner. Vendor and Wikidata rows
outrank machine-reported ones wherever they exist.

`cpu_specs` holds one row per sourced fact with a deep link to the exact
statement, and two sources are allowed to disagree — `precedence` decides which
is materialised onto `cpus`, so the disagreement stays visible.

**TDP, socket, lithography, clocks, launch price and release date are still
mostly empty.** Nothing in the benchmark feed carries them, and Wikidata has
almost none. They need Intel ARK and AMD's product pages, which are registered
as sources with the table ready for them, but **there is no importer for either
yet**; their specs can be entered against those sources by hand meanwhile.

## Styling

Tailwind CSS 4, with design tokens in `app/assets/tailwind/application.css`.
Two design languages share the file, each referenced verbatim in the repo:
the Vercel palette, depth and focus in `DESIGN.md`, and the Linear type and
spacing discipline in `linear.app/DESIGN.md`.

The canvas is achromatic (`#FAFAFA` ground, `#171717` text) with white cards
at 8px radii whose boundaries are shadows rather than CSS borders, 6px radii
on functional controls, and a single interactive blue (`#0072F5`) used only
for links, focus rings and active states. Focus uses the double-ring pattern.

Typography is Inter Variable with Linear's in-between weights — 510 for
emphasis, 590 for strong emphasis, nothing heavier — plus `cv01`/`ss03`
everywhere except code and inputs, and tracking that tightens as size grows.
Headings form a real scale (36px page titles, 16px section titles) instead of
tracked-out capitals: `.section-title` carries card and section headings in
sentence case, `.th-label` gives table headers a quiet 12px medium voice, and
the micro uppercase `.eyebrow` survives only for kickers and chart
annotations. Flowing text runs at 15px; sections breathe on a 24px rhythm
with generous card padding, while table rows stay dense.

Bars are drawn as upright ticks on a shared pitch by the `ticks` utility —
the track and the filled portion use the same gradient, so their ticks land
on one alignment grid. Names sit in a fixed first column so every bar starts
at the same x-position and lengths read against each other directly; each
figure's provenance sits under its bar rather than in the value column, which
is what keeps that alignment.

Because the name column already identifies each row, bars stay monochrome for
every row and the leader is marked by weight. Colour is never the only
carrier of meaning — the leading value is strong, and every figure is
printed next to its bar. Vendor identity lives in the small status dots,
the one place chromatic color appears, at dot scale.

Lining figures come from the `.figure` class rather than from `body`, since
tabular figures widen the hyphen.

## Tests

```bash
bin/rails test
```

109 tests covering the four upstream record schemas, the normalisation rules and
every rejection case, ingest idempotency and history, median/IQR/suppression,
the refusal to mix benchmark versions or workloads, the licensed-source
isolation, spec precedence and the agreement threshold, and the presentation
contract checked against rendered HTML.
# cpu-compare
