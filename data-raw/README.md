# data-raw

Scripts that generate the datasets shipped in `data/`.

The forecasts in `data/` are pre-generated and committed to the repository
so participants can load them directly and never need to fit Stan.
Regenerating them requires Stan and is a developer-only task.

## Datasets and the scripts that build them

| Script | Data objects refreshed |
|---|---|
| `epicurve.r` | `infection_times` |
| `generate-example-forecasts.r` | `rw_forecasts`, `stat_forecasts`, `mech_forecasts` |
| `generate-rt-forecast.r` | `rt_forecast` |

Each script writes its objects to `data/*.rda` via `usethis::use_data()`
and must be run from the package root.

## Prerequisites

`epicurve.r` needs only `epichains`, `dplyr`, `ggplot2` and `usethis`.

The two forecast scripts additionally need Stan:

- `cmdstanr`, which is not a participant dependency and is not in the
  package `Imports`/`Suggests`.
  Install it from the r-multiverse production snapshot pinned in the
  `Additional_repositories` field of `DESCRIPTION`
  (currently `https://production.r-multiverse.org/2026-06-15`):

  ```r
  install.packages(
    "cmdstanr",
    repos = "https://production.r-multiverse.org/2026-06-15"
  )
  ```

- a working CmdStan toolchain, installed once with:

  ```r
  cmdstanr::install_cmdstan()
  ```

The forecast scripts also load the installed `iddconf2026` package
(for `infection_times` and helpers such as `simulate_onsets()`), so
install the package before running them, and reinstall it if you have
just regenerated `infection_times`.

## Regenerating

Run from the package root, in this order:

```r
source("data-raw/epicurve.r")               # infection_times
source("data-raw/generate-example-forecasts.r")  # rw/stat/mech_forecasts
source("data-raw/generate-rt-forecast.r")   # rt_forecast
```

Each forecast script sources `data-raw/stan-tools.r` itself, so it does
not need to be sourced separately.
That file holds the Stan helpers (`nfidd_cmdstan_model()`,
`nfidd_sample()` and related) used only for data generation.

## Stan models

The Stan models used for data generation live in `data-raw/stan/`.
They were moved out of `inst/stan` so they no longer ship with the
installed package.
