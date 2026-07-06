# data-raw

Scripts that generate the datasets shipped in `data/`.

The forecasts in `data/` are pre-generated and committed to the repository
so participants can load them directly and never need to fit Stan.
Regenerating them requires Stan and is a developer-only task.

## Datasets and the scripts that build them

| Script | Data objects refreshed |
|---|---|
| `epicurve.r` | `infection_times` |
| `generate-onsets.r` | `onset_df` |
| `generate-example-forecasts.r` | `rw_forecasts`, `stat_forecasts`, `mech_forecasts` |
| `generate-rt-forecast.r` | `rt_forecast` |

Each script writes its objects to `data/*.rda` via `usethis::use_data()`
and must be run from the package root.

`onset_df` is the saved realisation of observed onsets that every session
loads with `data(onset_df)` and that all the forecasts are fit to.
`generate-onsets.r` reproduces the exact RNG stream that the forecasts were
originally fit to (`set.seed(12345)`, then the generation time PMF, the
incubation period PMF, then `simulate_onsets()`), so the committed
`rw_forecasts`, `stat_forecasts` and `mech_forecasts` remain consistent with
it and only need regenerating if `onset_df` itself changes.
The two forecast scripts read `data/onset_df.rda` directly, so run
`generate-onsets.r` before them.

## Prerequisites

`epicurve.r` needs only `epichains`, `dplyr`, `ggplot2` and `usethis`.

`generate-onsets.r` needs the installed `iddconf2026` package (for
`infection_times` and `simulate_onsets()`) and `usethis`.
Install the package before running it, and reinstall it if you have just
regenerated `infection_times`.

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
(for helpers such as `make_gen_time_pmf()` and `make_ip_pmf()`) and read
`data/onset_df.rda`, so install the package before running them and
regenerate `onset_df` first.

## Regenerating

Run from the package root, in this order:

```r
source("data-raw/epicurve.r")               # infection_times
source("data-raw/generate-onsets.r")        # onset_df
source("data-raw/generate-example-forecasts.r")  # rw/stat/mech_forecasts
source("data-raw/generate-rt-forecast.r")   # rt_forecast
```

`generate-onsets.r` needs only the installed `iddconf2026` package and
`usethis`; it does not need Stan.
The two forecast scripts read the `onset_df` written by `generate-onsets.r`,
so regenerate onsets first.
The `rw/stat/mech` forecasts are fit to `onset_df` and only need regenerating
if `onset_df` changes; `rt_forecast` is also fit to `onset_df`.

Each forecast script sources `data-raw/stan-tools.r` itself, so it does
not need to be sourced separately.
That file holds the Stan helpers (`nfidd_cmdstan_model()`,
`nfidd_sample()` and related) used only for data generation.

## Stan models

The Stan models used for data generation live in `data-raw/stan/`.
They were moved out of `inst/stan` so they no longer ship with the
installed package.
