library(NGCHM)
library(NGCHMSupportFiles)
library(future)
library(mime)
options(future.rng.onMisuse="ignore")

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
  future({
  parsed <- parse_multipart(req)
  if (is.element("data", names(parsed))){
    mat <- read.table(parsed$data$datapath, sep='\t', comment.char='&', header=T, row.names=1)
  }
  else{
    write("Error: No data file provided, no NGCHM generated!",stdout())
  }
  hm <- chmNew('temp', as.matrix(mat), rowDist='euclidean', colDist='euclidean', rowAgglom='average', colAgglom='average')

  if (is.element("bcodeB", names(parsed))){
    bcodeB <- read.table(parsed$bcodeB$datapath, sep='\t', comment.char='&', header=T, row.names=1)
    name <- names(bcodeB)
    if (length(name) >= 2){
      for(i in 2:length(name)){
        q <- bcodeB[, i]
        names(q) <- bcodeB[,1]
        if (startsWith(name[i], "META.")){
          metaName <- substr(name[i], 6, nchar(name[i]))
          hm <- chmAddMetaData(hm, 'col', metaName, q)
        }
        else{
          col <- chmNewCovariate(name[i], q )
          hm <- chmAddCovariateBar(hm, 'column', col)
        }
      }
    }
  }
  if (is.element("bcodeA", names(parsed))){
    bcodeA <- read.table(parsed$bcodeA$datapath, sep='\t', comment.char='&', header=T, row.names=1) 
    name <- names(bcodeA)
    if (length(name) >= 2){
      for(i in 2:length(name)){
        q <- bcodeA[,i]
        if (startsWith(name[i], "META.")){
          names(q) <- rownames(mat)
          metaName <- substr(name[i], 6, nchar(name[i]))
          hm <- chmAddMetaData(hm, 'row', metaName, q)
        }
        else{
          names(q) <- bcodeA[,1]
          row <- chmNewCovariate(name[i], q )
          hm <- chmAddCovariateBar(hm, 'row', row)
        }
      }
    }
  }
  tFile <- tempfile("NGCHMfile", fileext=".ngchm")
  chmExportToFile(hm, tFile)
  bin <- readBin(tFile, "raw", n=file.info(tFile)$size)
  file.remove(tFile)
  write("Finished generating NGCHM...", stdout())
  bin
  })
}

