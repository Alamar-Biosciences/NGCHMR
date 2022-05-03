#!/usr/bin/env Rscript
library(plumber)
pr("./NGCHM.r") %>% pr_run(host="0.0.0.0", port=8000)
