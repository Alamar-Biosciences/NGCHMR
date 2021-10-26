library(NGCHM)
library(NGCHMSupportFiles)
library(jsonlite)
library(future)

# Capture version and date information
verFile <- ""
if (file.exists(".git/refs/heads/main")){
  verFile <- ".git/refs/heads/main"
}else if(file.exists("main")){
  verFile <- "main"
}else if(file.exists("/workingDir/main")){
  verFile <- "/workingDir/main"
}

# Upload a protein expression file and return a NGCHM for use by daemon
#
# API entry point
#
# @param req JSON string, extract data matrix 
# @return Returns ngchm file
#* @serializer contentType list(type="application/octet-stream")
#* @post /ngchm
function(req){
#  future({
    body <- jsonlite::fromJSON(req$postBody)
    hm <- chmNew('temp', as.matrix(body))
    tFile <- tempfile("NGCHMfile", fileext=".ngchm")
    chmExportToFile(hm, tFile)
    bin <- readBin(tFile, "raw", n=file.info(tFile)$size)
    file.remove(tFile)
    write("Finished generating NGCHM...", stdout())
    bin
#  })
}

