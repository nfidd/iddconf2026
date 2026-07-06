# Stan tooling for (re)generating the packaged forecast datasets.
#
# These helpers are only needed by the data-raw generation scripts
# (generate-example-forecasts.r, generate-rt-forecast.r). They are NOT part
# of the installed package: the workshop sessions load pre-generated
# forecasts from data/ and never fit Stan, so participants do not need
# cmdstanr or a C++ toolchain. Source this file from a data-raw script after
# loading cmdstanr:
#
#   library("cmdstanr")
#   source("data-raw/stan-tools.r")
#
# The Stan models live in data-raw/stan/ (moved out of inst/stan so they no
# longer ship with the package).

# Path to the Stan code used for data generation. Assumes scripts are run
# from the package root (as usethis::use_data() also requires).
nfidd_stan_path <- function() {
  file.path("data-raw", "stan")
}

# Count the number of unmatched braces in a line
.unmatched_braces <- function(line) {
  ifelse(
    grepl("{", line, fixed = TRUE),
    length(gregexpr("{", line, fixed = TRUE)), 0
  ) -
    ifelse(
      grepl("}", line, fixed = TRUE),
      length(gregexpr("}", line, fixed = TRUE)), 0
    )
}

# Extract function names or content from Stan code
.extract_stan_functions <- function(
    content,
    names_only = FALSE,
    functions = NULL) {
  def_pattern <- "^(array\\[\\]\\s*)?(real|int|void|vector|row_vector|matrix)\\s+"
  func_pattern <- paste0(
    def_pattern,
    "(\\w+)\\s*\\("
  )
  func_lines <- grep(func_pattern, content, value = TRUE)
  # remove the func_pattern
  func_lines <- sub(def_pattern, "", func_lines)
  # get the next complete word after the pattern until the first (
  func_names <- sub("\\s*\\(.*$", "", func_lines)
  if (!is.null(functions)) {
    func_names <- intersect(func_names, functions)
  }
  if (names_only) {
    return(func_names)
  } else {
    func_content <- character(0)
    for (func_name in func_names) {
      start_line <- grep(paste0(def_pattern, func_name, "\\s*\\("), content)
      if (length(start_line) == 0) next
      end_line <- start_line
      brace_count <- 0
      # Ensure we find the first opening brace
      # Find first opening brace
      repeat {
        brace_count <- brace_count + .unmatched_braces(content[end_line])
        end_line <- end_line + 1
        if (brace_count > 0) break
      }

      # Continue until all braces are closed
      repeat {
        brace_count <- brace_count + .unmatched_braces(content[end_line])
        if (brace_count == 0) break
        end_line <- end_line + 1
      }

      func_content <- c(
        func_content,
        paste(content[start_line:end_line], collapse = "\n")
      )
    }
    return(func_content)
  }
}

# Get Stan function names from Stan files
nfidd_stan_functions <- function(stan_path = nfidd_stan_path()) {
  stan_files <- list.files(
    file.path(stan_path, "functions"),
    pattern = "\\.stan$", full.names = TRUE,
    recursive = TRUE
  )
  functions <- character(0)
  for (file in stan_files) {
    content <- readLines(file)
    functions <- c(
      functions, .extract_stan_functions(content, names_only = TRUE)
    )
  }
  unique(functions)
}

# Get Stan files containing specified functions
nfidd_stan_function_files <- function(
    functions = NULL,
    stan_path = nfidd_stan_path()) {
  # List all Stan files in the directory
  all_files <- list.files(
    file.path(stan_path, "functions"),
    pattern = "\\.stan$",
    full.names = TRUE,
    recursive = TRUE
  )

  if (is.null(functions)) {
    return(all_files)
  } else {
    # Initialize an empty vector to store matching files
    matching_files <- character(0)

    for (file in all_files) {
      content <- readLines(file)
      extracted_functions <- .extract_stan_functions(content, names_only = TRUE)

      if (any(functions %in% extracted_functions)) {
        matching_files <- c(matching_files, file)
      }
    }

    # remove the path from the file names
    matching_files <- sub(
      paste0(stan_path, "/"), "", matching_files
    )
    return(matching_files)
  }
}

# Load Stan functions as a string
nfidd_load_stan_functions <- function(
    functions = NULL, stan_path = nfidd_stan_path(),
    wrap_in_block = FALSE, write_to_file = FALSE,
    output_file = "nfidd_functions.stan") {
  stan_files <- list.files(
    file.path(stan_path, "functions"),
    pattern = "\\.stan$", full.names = TRUE,
    recursive = TRUE
  )
  all_content <- character(0)

  for (file in stan_files) {
    content <- readLines(file)
    if (is.null(functions)) {
      all_content <- c(all_content, content)
    } else {
      for (func in functions) {
        func_content <- .extract_stan_functions(
          content,
          names_only = FALSE,
          functions = func
        )
        all_content <- c(all_content, func_content)
      }
    }
  }

  # Add version comment
  version_comment <- paste(
    "// Stan functions from iddconf2026 version",
    utils::packageVersion("iddconf2026")
  )
  all_content <- c(version_comment, all_content)

  if (wrap_in_block) {
    all_content <- c("functions {", all_content, "}")
  }

  result <- paste(all_content, collapse = "\n")

  if (write_to_file) {
    writeLines(result, output_file)
    message("Stan functions written to: ", output_file, "\n")
  }

  return(result)
}

# List available Stan models
nfidd_stan_models <- function(stan_path = nfidd_stan_path()) {
  stan_files <- list.files(
    stan_path,
    pattern = "\\.stan$", full.names = FALSE,
    recursive = FALSE
  )

  # Remove .stan extension
  model_names <- tools::file_path_sans_ext(stan_files)

  return(model_names)
}

# Create a CmdStanModel with the data-generation Stan functions
nfidd_cmdstan_model <- function(
    model_name = NULL,
    model_file = NULL,
    include_paths = getOption("nfidd.stan_path", nfidd_stan_path()),
    ...) {

  # Determine which Stan file to use
  if (!is.null(model_file)) {
    # Use custom model file
    if (!file.exists(model_file)) {
      stop(sprintf("Custom model file '%s' not found", model_file))
    }
    stan_model <- model_file
  } else if (!is.null(model_name)) {
    # Use model from the data-raw Stan directory
    stan_model <- file.path(nfidd_stan_path(), paste0(model_name, ".stan"))

    if (!file.exists(stan_model)) {
      stop(sprintf(
        "Model '%s.stan' not found in %s", model_name, nfidd_stan_path()
      ))
    }
  } else {
    stop("Either model_name or model_file must be provided")
  }

  cmdstanr::cmdstan_model(
    stan_model,
    include_paths = include_paths,
    ...
  )
}

# Sample from a CmdStanModel with course defaults
nfidd_sample <- function(model,
                         iter_warmup = 500,
                         iter_sampling = 500,
                         parallel_chains = 4,
                         save_warmup = FALSE,
                         ...) {
  model$sample(
    iter_warmup = iter_warmup,
    iter_sampling = iter_sampling,
    parallel_chains = parallel_chains,
    save_warmup = save_warmup,
    ...
  )
}
