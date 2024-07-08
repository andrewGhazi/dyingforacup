data {
  int<lower=1> N;
  int<lower=1> N_pred;
  int<lower=1> D;
  array[N] vector[D] x;
  array[N_pred] vector[D] x_pred;
  vector[N] y;

}

transformed data {
  vector[N] mu = rep_vector(0, N);
  real delta = 1e-9;
  // real<lower=0> sigma=1.0;
}

parameters {
  real<lower=0> rho; // length scale
  real<lower=0> alpha; // amplitude
  real<lower=0> sigma; // I'm giving ratings with a known variance of 1
}

transformed parameters {
  matrix[N, N] L_K;
  matrix[N, N] K = gp_exp_quad_cov(x, alpha, rho);

  // diagonal elements
  for (n in 1:N) {
    K[n, n] = K[n, n] + sigma^2;
  }

  L_K = cholesky_decompose(K);
}

model {
  rho ~ inv_gamma(3,3);
  // rho ~ std_normal();
  // alpha ~ std_normal();
  alpha ~ inv_gamma(3,3);
  sigma ~ student_t(3, 0, .2);

  y ~ multi_normal_cholesky(mu, L_K);
}

generated quantities {
  vector[N_pred] f_mean;
  vector[N_pred] f_star;
  {
    matrix[N, N_pred] K_x_x_pred = gp_exp_quad_cov(x, x_pred, alpha, rho);
    vector[N] K_div_y = mdivide_right_tri_low(mdivide_left_tri_low(L_K, y)', L_K)';
    vector[N_pred] f_mu = K_x_x_pred' * K_div_y;
    matrix[N, N_pred] v_pred = mdivide_left_tri_low(L_K, K_x_x_pred);
    matrix[N_pred, N_pred] cov_f2 = gp_exp_quad_cov(x_pred, alpha, rho) - v_pred' * v_pred;
    
    f_mean = multi_normal_rng(f_mu, add_diag(cov_f2, rep_vector(delta, N_pred)));
    
    for (i in 1:N_pred) {
      f_star[i] = normal_rng(f_mean[i], sigma);
    }
  }
  
  
}
