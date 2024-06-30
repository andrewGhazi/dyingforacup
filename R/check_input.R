get_params = function(dat) {
  grep("rating", names(dat), value = TRUE, invert = TRUE)
}

all_within = function(param_vec, range_vec) {
  all((param_vec >= range_vec[1]) & (param_vec <= range_vec[2]))
}


#' Check input data.frame
#' @description
#' The input data frame should have a limited number of columns and at least two rows
#' @param dat data frame input
#' @param call calling environment
check_df = function(dat, call = rlang::caller_env()) {
  cn = colnames(dat)
  
  if (!("rating" %in% cn)) cli::cli_abort("No `rating` column detected in input.", call = call)
  
  cli::cli_alert("Detected brew parameters {.val {cn[!(cn %in% 'rating')]}}")
  
  # if (nrow(dat) < 2) cli::cli_abort("Input needs at least two existing observations.", call = call)
}

check_param_olap = function(dat, param_ranges) {
  dat_params = get_params(dat)
  rng_params = get_params(param_ranges)
  
  param_int = intersect(dat_params, rng_params)
  
  all_in_int = all(dat_params %in% param_int) & all(rng_params %in% param_int)
  
  if (!all_in_int) cli::cli_warn("Non-overlapping columns between data and parameter ranges will be dropped.")
  
}

check_ranges = function(dat, param_ranges, call = rlang::caller_env()) {
  params = get_params(dat)
  
  check_param_olap(dat, param_ranges)
  
  within_ranges = mapply(all_within,
                         dat |> get_vars(params), param_ranges |> get_vars(params))
  
  if (!all(within_ranges)) cli::cli_abort("Provided parameter values fall outside the specified ranges. Those with values outside the provided ranges are {.val {names(within_ranges[!within_ranges])}}",
                                          call = call)
  
  list(dat |> get_vars(c(params, "rating")), param_ranges |> get_vars(params))
}
