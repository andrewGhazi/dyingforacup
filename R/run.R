get_grid_vec = function(param_id, param_range) {
  if (param_id == "grinder_setting") {
    res = seq(param_range[1], param_range[2], by = .5)
  } else if (param_id == "temp") {
    res = seq(param_range[1], param_range[2], by = 5)
  } else if (param_id == "bloom_time") {
    res = seq(param_range[1], param_range[2], by = 10)
  } else {
    res = seq(param_range[1], param_range[2], length.out = 6)
  }
  
  res
}

form_x_grid = function(max_grid_size,
                       param_ranges) {
  
  params = get_params(param_ranges)
  
  vec_list = mapply(get_grid_vec,
                    params, param_ranges,
                    SIMPLIFY = FALSE)
  
  res = expand.grid(vec_list) |> qDT()
  
  if (nrow(res) > max_grid_size) cli::cli_abort("Automated grid exceeded the specified {.var max_grid_size}. Either provide your own grid or increase {.var max_grid_size}")
  
  res
}

get_x_grid = function(max_grid_size,
                      param_ranges, param_grid) {
  
  if (!is.null(param_grid)) {
    x_grid = param_grid
  } else {
    x_grid = form_x_grid(max_grid_size,
                        param_ranges)
  }
  
  x_grid
}


#' Create a range data frame
#' @description This function creates an example data frame of mins and maxs for brew
#'   parameter settings. That is, the range of grinder settings I want to search is from 4
#'   to 14, temperatures from 170 to 210F, and bloom times from 0 to 60s.
#'
#' @export
create_ranges = function() {
  data.frame(grinder_setting = c(4,14),
             temp = c(170, 210),
             bloom_time = c(0, 60))
}

get_centers_and_widths = function(param_ranges) {
  centers = param_ranges |> sapply(fmean)
  widths  = (param_ranges |> sapply(diff)) / 2
  list(centers, widths)
}

center_grid = function(x_grid, param_ranges) {
  cents_widths = get_centers_and_widths(param_ranges)
  
  centers = cents_widths[[1]]
  widths  = cents_widths[[2]]
  
  res = x_grid |> 
    TRA(centers) |> 
    TRA(widths, FUN = "/") |> 
    TRA(rep(3, ncol(x_grid)), FUN = "*")
  
  names(res) = paste0(names(res), "_cent")
  res
}

center_dat = function(dat, param_ranges) {
  cents_widths = get_centers_and_widths(param_ranges)
  
  centers = cents_widths[[1]]
  widths  = cents_widths[[2]]
  
  params = get_params(dat)
  
  res = dat |> 
    get_vars(params) |> 
    TRA(centers) |> 
    TRA(widths, FUN = "/") |> 
    TRA(rep(3, length(params)), FUN = "*")
  
  names(res) = paste0(names(res), "_cent")
  
  res |> 
    add_vars(dat$rating)
}

#' Run the GP
#' @param dat data frame input of brew parameters and rating
#' @param ... arguments passed to cmdstanr's sample method
#' @param max_grid_size maximum number of grid points to evaluate
#' @param param_ranges upper and lower limits of parameter ranges to evaluate (ignored if param_grid is specified directly)
#' @param param_grid user-specified grid of brew parameters to evaluate GP at
#' @details
#' The function \code{\link[dyingforacup:create_ranges]{dyingforacup::create_ranges()}} will create an example range df.
#' 
#' @export
run_gp = function(dat, ..., max_grid_size = 2000,
                  param_ranges = create_ranges(), param_grid = NULL) {
  
  check_df(dat)
  cr_res = check_ranges(dat, param_ranges)
  dat = cr_res[[1]]; param_ranges = cr_res[[2]]
  
  x_grid = get_x_grid(max_grid_size, param_ranges, param_grid)
  x_grid_cent = center_grid(x_grid, param_ranges)
  
  centered_dat = center_dat(dat, param_ranges)
  
  X = centered_dat |> get_vars("_cent", regex=TRUE) |> qM()
  
  list(run_gp_model(X = X, y = dat$rating, X_pred = x_grid_cent, ...),
       x_grid,
       x_grid_cent)
}

#' Suggest the next point to try
#' @inheritParams run_gp
#' @param ... arguments passed to cmdstanr's sample method
#' @param offset expected improvement hyperparameter. Higher values encourage more
#'   exploration. Interpreted on the same scale as ratings.
#' @export
suggest_next = function(dat, ..., max_grid_size = 2000,
                        param_ranges = create_ranges(), param_grid = NULL,
                        offset = .25) {
  
  run_res = run_gp(dat, ...)
  
  gp_res = run_res[[1]]
  x_grid = run_res[[2]]
  x_grid_cent = run_res[[3]]
  
  obs_max = max(dat$rating)
  
  offset = .25
  minus_max = qM(gp_res |> get_vars("f_star", regex = TRUE)) - obs_max - offset
  
  w = 1*(minus_max > 0)
  
  acq = minus_max * w
  
  max_pred_dens = fsum(acq) |> which.max()
  
  if (max_pred_dens == 1) cli::cli_warn("Selected the first grid point as maximum of the acquisition function. You may need to run the chains for longer or lower {.var offset}.")
  
  # pred_g = x_grid[max_pred_dens,,drop=FALSE][,"gc"]
  
  # acq_post = data.table(variable = colnames(acq),
  #                       mean = acq |> colMeans(),
  #                       i = 1:ncol(acq))
  # 
  # post_range = acq_post$mean |> range()
  
  # qDT(x_grid) |> mtt(i = 1:nrow(x_grid)) |>
  #   sbt(dplyr::near(gc, pred_g)) |>
  #   join(acq_post, on = "i", validate = "1:1") |>
  #   ggplot(aes(tc, bc)) +
  #   geom_tile(aes(fill = mean)) +
  #   scale_fill_viridis_c(limits = post_range)
  
  list(draws_df = gp_res, 
       x_grid = x_grid, 
       suggested = x_grid[max_pred_dens,] )
}
