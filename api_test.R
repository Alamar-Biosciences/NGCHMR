#!/usr/bin/env Rscript
# plumber.R
library(httr)
library(jsonlite)
seed=TRUE
options(stringsAsFactors=F)
url <- "http://127.0.0.1:8000"
data <- read.table("test_data.txt", sep="\t", header=T, row.names=1)
raw.result <- POST(url=url, 
                   path="ngchm", 
                   body=data, 
                   encode ="json")
writeBin((raw.result$content), "test.ngchm", useBytes=TRUE)
write("Wrote results to 'test.nhchm'!", stdout())
