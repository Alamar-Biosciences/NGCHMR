#!/usr/bin/env Rscript
# plumber.R
library(httr)
library(jsonlite)
options(stringsAsFactors=F)
url <- "http://127.0.0.1:8000"

raw.result <- POST(url=url, 
                   path="ngchm", 
                   body=list( data = read.table("Book1.txt", sep="\t", header=T)
                             ), 
                   encode ="json")
qPCRResults <-fromJSON(rawToChar(raw.result$content))
write(capture.output(qPCRResults), stdout())

