#!/usr/bin/env Rscript
library(plumber)
library(future)
workers <- max(2, availableCores(), na.rm=T)
plan(cluster, workers=workers) # do not use multicore (possible garbage collection issue)
args = commandArgs(trailingOnly=T)
PORT <- if (length(args) == 0 ) 8000 else args[1]
if (file.exists("/workingDir")){
  pr("/workingDir/NGCHM.r") %>% pr_run(host="0.0.0.0", port=as.integer(PORT));
} else{
  pr("./NGCHM.r") %>% pr_run(host="0.0.0.0", port=as.integer(PORT));
}
