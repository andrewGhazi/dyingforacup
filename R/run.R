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
#'   to 14, temperatures from 170 to 210F, and bloom times from 0 to 60s. This sets the
#'   range of the grid of the brew parameter space that is evaluated.
#'
#'   Brew parameters named `grinder_setting`, `temp`, and `bloom_time` get special
#'   treatment when the grid is created. They specifically get designated step sizes of
#'   0.5, 5, and 10 respectively. 
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
#' @param param_ranges upper and lower limits of parameter ranges to evaluate (ignored if
#'   param_grid is specified directly)
#' @param param_grid user-specified grid of brew parameters to evaluate GP at
#' @details The function
#' \code{\link[dyingforacup:create_ranges]{dyingforacup::create_ranges()}} will create an
#' example range df.
run_gp = function(dat, ..., max_grid_size = 2000,
                  param_ranges = create_ranges(), param_grid = NULL) {
  
  check_df(dat)
  
  if (is.null(param_grid)) {
    cr_res       = check_ranges(dat, param_ranges)
    dat          = cr_res[[1]]
    param_ranges = cr_res[[2]]
    x_grid = get_x_grid(max_grid_size, param_ranges, param_grid)
    x_grid_cent = center_grid(x_grid, param_ranges)
    centered_dat = center_dat(dat, param_ranges)
  } else {
    # TODO: make sure this handles uneven user-provided grids correctly.
    emp_ranges = param_grid |> lapply(frange) |> qDT()
    x_grid = param_grid
    x_grid_cent = param_grid |> center_grid(emp_ranges)
    centered_dat = center_dat(dat, emp_ranges)
  }
  
  X = centered_dat |> get_vars("_cent", regex = TRUE) |> qM()
  
  list(run_gp_model(X = X, y = dat$rating, X_pred = x_grid_cent, ...),
       x_grid)
}

#' Suggest the next point to try
#' @inheritParams run_gp
#' @param ... arguments passed to cmdstanr's sample method
#' @param offset expected improvement hyperparameter. Higher values encourage more
#'   exploration. Interpreted on the same scale as ratings.
#' @param lambda tradeoff between weighting posterior predictive variance and expected
#'   improvement at grid values.
#' @details The acquisition function is \code{lambda*f_star_var + (1-lambda)*exp_imp}.
#'   Higher values of lambda up-weight posterior predictive variance, leading to more
#'   exploration over exploitation. Lower lambda values up-weight expected improvement
#'   over \code{max(dat$rating) - offset}.
#'
#'   For the sake of simplicity, the range of each parameter in the grid is linearly
#'   scaled to an N-dimensional hypercube that spans -3 to 3 on each edge. So the model is
#'   insensitive to the range of grid values. It won't make a difference if your grinder
#'   shows different numbers or something.
#'
#'   It's normal for the sampling to slow down dramatically after the warmup phase. This
#'   is because while it's fast to fit a GP to a tiny number of observations, it's much
#'   more expensive to evaluate the GP over the parameter grid. This happens in the
#'   generated quantities block of the model, which only gets evaluated in the sampling
#'   phase, which is why it's slow. Whatever man. My CPU has 16 physical cores.
#' @returns a list with elements:
#' \itemize{
#'   \item{draws_df}{a draws data frame of model parameters and grid point predictive draws f_star}
#'   \item{acq_df}{a data table of acquisition function values and corresponding grid point values}
#'   \item{suggested}{the row of \code{acq_df} that maximizes the acquisition function}
#' }
#'
#' @export
suggest_next = function(dat, ..., max_grid_size = 2000,
                        param_ranges = create_ranges(), param_grid = NULL,
                        offset = .25,
                        lambda = .1) {
  
  run_res = run_gp(dat, 
                   max_grid_size = max_grid_size, 
                   param_ranges = param_ranges, 
                   param_grid = param_grid, 
                   ...)
  
  gp_res = run_res[[1]]
  x_grid = run_res[[2]]
  
  obs_max = max(dat$rating)
  
  f_star_mat = qM(gp_res |> get_vars("f_star", regex = TRUE))
  f_mean_mat = qM(gp_res |> get_vars("f_mean", regex = TRUE))
  
  # expected improvement ----
  minus_max = f_star_mat - (obs_max - offset)
  
  w = 1*(minus_max > 0)
  
  exp_imp = fmean(minus_max * w)
  
  max_pred_dens = exp_imp |> which.max()
  
  if (all(exp_imp < .Machine$double.eps^0.5)) cli::cli_warn("All expected improvement values near zero. You may need to run the chains for longer or raise {.var offset}.")
  
  # posterior uncertainty ----
  f_mean_sd = f_mean_mat |> fsd()
  
  # combined expected improvement and posterior uncertainty ----
  
  combined_acq = lambda*f_mean_sd + (1-lambda)*exp_imp
  
  acq_df = data.table(post_sd = f_mean_sd,
                      exp_imp = exp_imp,
                      acq = combined_acq) |> 
    add_vars(x_grid) 
  
  suggest = acq_df |> sbt(whichv(acq, fmax(acq))) 
  
  list(draws_df = gp_res, 
       acq_df = acq_df, 
       suggested = suggest )
}

#' Suggest a coffee-related tune
#' 
#' @details
#' Some are more rare than others, collect all 8!
#' 
#' @export
suggest_tune = function() {
  msgs = c("How 'bout this one? Donk:")
  
  song_info = data.table(u = c("https://www.youtube.com/watch?v=RJC9DXQAd7U", 
                               "https://www.youtube.com/watch?v=zTbJBnkRkFo",
                               "https://www.youtube.com/watch?v=lpOktupkl0c",
                               "https://www.youtube.com/watch?v=PU_kd9uJQEI",
                               "https://www.youtube.com/watch?v=iP6IUqrFHjw",
                               "https://www.youtube.com/watch?v=cm3YM_9iW_s",
                               "https://www.youtube.com/watch?v=_rp4tGqRhWA",
                               "https://www.youtube.com/watch?v=nsFS8tt_3fs"),
                         info = c('Dethklok - "Duncan Hills Coffee Jingle"',
                                  'Frank Sinatra - "The Coffee Song"',
                                  'Black Flag - "Black Coffee"',
                                  'Humble Pie - "Black Coffee"',
                                  'The Ink Spots - "The Java Jive"',
                                  'Otis Redding - "Cigarettes and Coffee"',
                                  "Marty Robbins - \"Smokin' Cigarettes And Drinkin\' Coffee Blues\"",
                                  'Anthrax - "Cupajoe"')) |> 
    mtt(p = rev(1:fnobs(u)))
  
  i = sample(nrow(song_info), 1, prob = song_info$p)
  
  cli::cli_inform("How 'bout this one? {.emph Donk}:")
  cli::cli_inform("")
  cli::cli_inform("{.strong {song_info$info[i]}}")
  cli::cli_inform("{.url {song_info$u[i]}}")
}

