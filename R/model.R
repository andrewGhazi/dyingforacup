#' @title Fit the GP model.
#' @family models
#' @description Fit the GP Stan model and return posterior summaries.
#' @returns a draws data frame
#' @param X a matrix of scaled brew parameters
#' @param y Numeric vector of ratings (NORMAL scale, not 0-10!)
#' @param X_pred a matrix of grid points of in scaled brew parameter space to evaluate the GP at
#' @param ... Named arguments to the `sample()` method of CmdStan model
#' @param verbose logical indicating whether to print messages
#'   objects: <https://mc-stan.org/cmdstanr/reference/model-method-sample.html>
#' @examples
#' if (instantiate::stan_cmdstan_exists()) {
#'   run_gp_model(y = rnorm(5))
#' }
run_gp_model = function(X, y, X_pred, ..., verbose) {
  
  model = instantiate::stan_package_model(
    name = "gp_mod",
    package = "dyingforacup"
  )
  
  data_list = list(N      = length(y),
                   N_pred = nrow(X_pred),
                   D      = ncol(X),
                   x      = X,
                   x_pred = X_pred,
                   y      = y)
  
  fit = model$sample(data = data_list,
                     ...)
  
  fit$draws(format = "data.frame",
            variables = c("alpha", "rho", "sigma", "f_star"))
}
