library("iddconf2026")
library("usethis")

# See data-raw/README.md for prerequisites and the regeneration order.
# Generate the saved dataset of observed symptom onsets used across the
# sessions and by the forecast-generation scripts. Sessions load this saved
# dataset with data(onset_df) rather than re-simulating it, so their observed
# data is always the same realisation the forecasts were fit to.

# This reproduces exactly the pre-fit RNG stream of
# data-raw/generate-example-forecasts.r (set.seed(12345), then the generation
# time PMF, the incubation period PMF, then simulate_onsets()). Keeping this
# order byte-identical means the rw/stat/mech forecasts already committed in
# data/ remain consistent with onset_df and do not need regenerating.
set.seed(12345)

gen_time_pmf <- make_gen_time_pmf()
ip_pmf <- make_ip_pmf()
onset_df <- simulate_onsets(
  make_daily_infections(infection_times), ip_pmf
)

usethis::use_data(onset_df, overwrite = TRUE)
