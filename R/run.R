#' @export
run_gp = function(dat, ...) {
  
  check_df(dat)
  
  # TODO adapt centering/scaling, generalize to arbitrary # of parameters
  dat = dat |>
    mtt(gs_cent = (grinder_setting - 9) / 5 * 3,
        temp_cent = (temp - 190) / (20) * 3,
        bloom_cent = (bloom_time - 30) / 30 * 3) |>
    qDT()
  
  g_map = data.table(g = seq(4,14, by = .5)) |>
    mtt(gc = (g - 9) / 5 * 3)
  
  t_map = data.table(t = seq(170, 210, by = 5),
                     tc = (seq(170, 210, by = 5) - 190) / 20 * 3)
  
  b_map = data.table(b = seq(0, 60, by = 10),
                     bc = ((seq(0, 60, by = 10) - 30) / 30) * 3 )
  
  x_grid = expand.grid(gc = g_map$gc,
                       tc = t_map$tc,
                       bc = b_map$bc) |>
    qM()
  
  X = dat |> slt(gs_cent, temp_cent, bloom_cent) |> qM()
  
  list(run_gp_model(X, dat$rating, x_grid, ...),
       x_grid)
}

#' @export
suggest_next = function(dat, x_grid, ...) {
  
  run_res = run_gp(dat, ...)
  gp_res = run_res[[1]]
  x_grid = run_res[[2]]
  
  obs_max = max(dat$rating)
  
  offset = .25
  minus_max = qM(gp_res |> get_vars("f_star", regex = TRUE)) - obs_max - offset
  
  w = 1*(minus_max > 0)
  
  acq = minus_max * w
  
  max_pred_dens = fsum(acq) |> which.max()
  
  if (max_pred_dens == 1) cli::cli_warn("Selected the first grid point as maximum of the acquisition function. You may need to run the chains for longer.")
  
  pred_g = x_grid[max_pred_dens,,drop=FALSE][,"gc"]
  
  acq_post = data.table(variable = colnames(acq),
                        mean = acq |> colMeans(),
                        i = 1:ncol(acq))
  
  post_range = acq_post$mean |> range()
  
  # qDT(x_grid) |> mtt(i = 1:nrow(x_grid)) |>
  #   sbt(dplyr::near(gc, pred_g)) |>
  #   join(acq_post, on = "i", validate = "1:1") |>
  #   ggplot(aes(tc, bc)) +
  #   geom_tile(aes(fill = mean)) +
  #   scale_fill_viridis_c(limits = post_range)
  
  g_map = data.table(g = seq(4,14, by = .5)) |>
    mtt(gc = (g - 9) / 5 * 3)
  
  t_map = data.table(t = seq(170, 210, by = 5),
                     tc = (seq(170, 210, by = 5) - 190) / 20 * 3)
  
  b_map = data.table(b = seq(0, 60, by = 10),
                     bc = ((seq(0, 60, by = 10) - 30) / 30) * 3 )
  
  x_grid[max_pred_dens,,drop=FALSE] |>
    qDT() |>
    join(g_map, verbose = FALSE) |>
    join(t_map, verbose = FALSE) |>
    join(b_map, verbose = FALSE)
  
}
