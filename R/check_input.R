#' Check input data.frame
#' @description
#' The input data frame should have a limited number of columns and at least two rows
#' 
check_df = function(dat, call = rlang::caller_env()) {
  cn = colnames(dat)
  
  if (!("rating" %in% cn)) cli::cli_abort("No `rating` column detected in input.", call = call)
  
  cli::cli_alert("Detected brew parameters {.val {cn[!(cn %in% 'rating')]}}")
  
  # if (nrow(dat) < 2) cli::cli_abort("Input needs at least two existing observations.", call = call)
}
