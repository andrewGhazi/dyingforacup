
<!-- README.md is generated from README.Rmd. Please edit that file -->

# dyingforacup

[DO YOU FOLKS LIKE
COFFEE?!](https://www.youtube.com/watch?v=RJC9DXQAd7U)

<!-- badges: start -->
<!-- badges: end -->

This is the package I use to optimize my coffee brewing with [Bayesian
Optimization](https://www.youtube.com/watch?v=wZODGJzKmD0)

## Installation

You need to install
[`cmdstanr`](https://mc-stan.org/cmdstanr/index.html) to use this
package:

``` r
# we recommend running this is a fresh R session or restarting your current session
install.packages("cmdstanr", repos = c("https://stan-dev.r-universe.dev", getOption("repos")))
```

You can install the development version of `dyingforacup` like so:

``` r
remotes::install_github('andrewGhazi/dyingforacup', type = "source")
```

## Example

Give the `run_gp()` function a data frame of brew parameters with an

``` r
library(dyingforacup)

dat = data.frame(grinder_setting = c(8, 193, 25), 
                 temp = c(7, 195, 20), 
                 bloom_time = c(9, 179, 45), 
                 rating = c(1.1, -.7, -1))

run_gp(dat)
```
