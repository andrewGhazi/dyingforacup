
<!-- README.md is generated from README.Rmd. Please edit that file -->

# dyingforacup

[DO YOU FOLKS LIKE
COFFEE?!](https://www.youtube.com/watch?v=RJC9DXQAd7U)

<!-- badges: start -->
<!-- badges: end -->

This is the package I use to optimize my coffee brewing with [Bayesian
Optimization](https://www.youtube.com/watch?v=wZODGJzKmD0).

## Installation

You need to install
[`cmdstanr`](https://mc-stan.org/cmdstanr/index.html) to use this
package:

``` r
# we recommend running this is a fresh R session or restarting your current session
install.packages("cmdstanr", repos = c("https://stan-dev.r-universe.dev", getOption("repos")))
```

After that, you can install the development version of `dyingforacup`
like so:

``` r
remotes::install_github('andrewGhazi/dyingforacup', type = "source")
```

## Example

Give the `suggest_next()` function a data frame of brew parameters with
ratings and it will suggest a point to try next that has high predicted
probability of improving the rating.

``` r
library(dyingforacup)
options(mc.cores = 4)

dat = data.frame(grinder_setting = c(  8,    7,   9), 
                 temp            = c(193,  195, 179),
                 bloom_time      = c( 25,   20,  45),
                 rating          = c(1.1, -0.7,  -1))

suggest_next(dat,
             iter_sampling = 4000, 
             refresh = 0, 
             show_exceptions = FALSE, 
             adapt_delta = .95, 
             parallel_chains = 4)
```

## 1D Example animation

## TODO list

Easy:

- User prior input
- Viz functions

Medium:

- Non-normal outcome
- Fast GP approximations for 1D/2D datasets

Hard:

- ARD / parameter-specific length-scales
- heteroscedasticity

Nightmare:

- Fast GP approximations for 3D+
  - I think this would require writing my own ND FFT function?
