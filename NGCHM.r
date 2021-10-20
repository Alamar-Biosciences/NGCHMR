library(NGCHM)
library(NGCHMSupportFiles)
library(jsonlite)

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
#* @post /ngchm
#* @get /ngchm
function(req){
  future({
    body <- jsonlite::fromJSON(req$postBody)
    hm <- chmNew('temp', body$data)
    tFile <- tempfile("NGCHMfile", fileext=".ngchm")
    chmExportToFile(hm, tFile)

    write("Finished generating NGCHM...", stdout())
    return(include_file(tFile))
  })
}

