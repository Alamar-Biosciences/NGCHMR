#!/usr/bin/env Rscript
# plumber.R
library(httr)
 seed=TRUE
options(stringsAsFactors=F)
url <- "http://localhost:8000"
# bcodeA and bcodeB are optional in this POST request
raw.result <- POST(url=url, 
                   path="ngchm", 
                   body=list(data=upload_file("test_data.txt"), bcodeB=upload_file("bcodeB.txt"), bcodeA=upload_file("bcodeA.txt")), encode="multipart")
writeBin((raw.result$content), "test.ngchm", useBytes=TRUE)
write("Wrote results to 'test.nhchm'!", stdout())

