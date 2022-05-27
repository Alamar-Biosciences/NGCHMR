#!/usr/bin/env Rscript
library(plumber)
pr("/workingDir/NGCHM.r") %>% pr_run(host="0.0.0.0", port=8000)
#pr("./NGCHM.r") %>% pr_run(host="0.0.0.0", port=8000)
