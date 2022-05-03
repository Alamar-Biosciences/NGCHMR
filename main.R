#!/usr/bin/env Rscript
library(plumber)
pr("./NGCHM.r") %>% pr_run(host="127.0.0.1", port=8000)
