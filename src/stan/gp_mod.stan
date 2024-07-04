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
  real<lower=0> alpha; // wiggliness
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
  // alpha ~ std_normal();
  alpha ~ inv_gamma(3,3);
  sigma ~ student_t(6, 0, .2);

  y ~ multi_normal_cholesky(mu, L_K);
}

generated quantities {
  vector[N_pred] f_star;
  {
    matrix[N, N_pred] K_x_x_pred = gp_exp_quad_cov(x, x_pred, alpha, rho);
    vector[N] K_div_y = mdivide_right_tri_low(mdivide_left_tri_low(L_K, y)', L_K)';
    f_star = K_x_x_pred' * K_div_y;
  }

  for (i in 1:N_pred) {
    f_star[i] += normal_rng(0, sigma);
  }
}
