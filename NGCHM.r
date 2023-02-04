library(NGCHM)
library(NGCHMSupportFiles)
library(future)
library(mime)
library(xml2)
library(colorspace)
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

# Upload the XML file and output an RDS for storage
#
# API entry point
#
# @param req JSON string
# @return Returns an RDS file
#* @serializer contentType list(type="application/octet-stream")
#* @post /rds
function(req){
  # import the XML loading script here and return an rds file
  write("Finished generating RDS file...", stdout())
}

# Upload a protein expression file and return a NGCHM for use by daemon
#
# API entry point
#
# @param req JSON string, extract data matrix 
# @return Returns ngchm file
#* @param data:file
#* @param method
#* @param keepControls
#* @param bcodeBin:file
#* @param bcodeAin:file
#* @param IPC
#* @param NC
#* @param rowDist
#* @param colDist
#* @param rowAgglom
#* @param colAgglom
#* @post /ngchm
ngchm <- function(data, method="IC", keepControls=FALSE, bcodeBin="", bcodeAin="", 
                  IPC=c('InterPlateControl'), NC=c('NegativeControl'), IC=c('mCherry'),
                  rowDist='euclidean', colDist='euclidean', rowAgglom='average', colAgglom='average'){
  future({
  root <- xml_root(read_xml(toString(data)))

  # Read BarcodeAs
  x <- NULL; y <- NULL;
  for (barcodeA in xml_find_all(root, ".//BarcodeA")){
    for (bcodeA in xml_find_all(barcodeA, ".//Barcode")){
      x <- if(is.null(x)) xml_attrs(bcodeA) else rbind(x, xml_attrs(bcodeA))
      y <- if(is.null(y)) xml_text(bcodeA) else  rbind(y, xml_text(bcodeA))
    }
    colnames(y) <- "Target"
    BarcodeA <- if (ncol(x) == 1) cbind(x, y) else cbind(x[, 1], y, x[, 2:ncol(x)])
    colnames(BarcodeA)[1] <- "name"
    rownames(BarcodeA) <- NULL;
    BarcodeA <- as.data.frame(BarcodeA)
  }

  # Read BarcodeBs
  x <- NULL; y <- NULL;
  for (barcodeB in xml_find_all(root, ".//BarcodeB")){
    for (bcodeB in xml_find_all(barcodeB, ".//Barcode")){
      if (keepControls || (!grepl(paste(NC, collapse="|"), xml_text(bcodeB)) && !grepl(paste(IPC, collapse="|"), xml_text(bcodeB)))){
        x <- if(is.null(x)) xml_attrs(bcodeB) else rbind(x, xml_attrs(bcodeB))
        y <- if(is.null(y)) xml_text(bcodeB)  else rbind(y, xml_text(bcodeB))
      }
    }
    colnames(y) <- "Sample"
    BarcodeB <- if (ncol(x) == 1) cbind(x, y) else cbind(x[, 1], y, x[, 2:ncol(x)])
    colnames(BarcodeB)[1] <- "name"
    rownames(BarcodeB) <- NULL;
    BarcodeB <- as.data.frame(BarcodeB)
  }

  # Read the actual data for the heatmap
  storage = as.data.frame(matrix(nrow=length(unique(BarcodeA$Target)), ncol=length(unique(BarcodeB$Sample))))
  colnames(storage) = unique(BarcodeB$Sample)
  rownames(storage) = unique(BarcodeA$Target)
  for (sample in xml_find_all(root, ".//Sample")){
    col <- which(colnames(storage) == xml_attr(sample, 'name'))
    for (combined in xml_find_all(sample, ".//Combined")){ # "Combined" - Sample, or "Replicate"
      for (method2 in xml_find_all(combined, ".//Method")){
        if(xml_attr(method2, 'name') == method){ # "raw", "IC", or "TC"
          for(target in xml_find_all(method2, ".//Target")){
            targetName <- BarcodeA[which(BarcodeA$name == xml_attr(target, 'name')), ]$Target
            row <- which(rownames(storage) == targetName)
            storage[row, col] <- as.numeric(xml_text(target)) 
          }
        }
      }
    }
  }

  # Create the heatmap
  hm <- chmNew('temp', as.matrix(storage), rowDist=rowDist, colDist=colDist, rowAgglom=rowAgglom, colAgglom=colAgglom)

  # BarcodeB / Targets / Covariates processing 
  if (bcodeBin != ""){
    bcodeB <- read.table(text=toString(bcodeBin), sep='\t', comment.char='&', header=T, row.names=1, na.strings=c())
    name <- colnames(bcodeB)
  }
  else{
    name <-names(BarcodeB)[2:ncol(BarcodeB)]
    bcodeB <- BarcodeB[, 2:ncol(BarcodeB)]
  }
  if (length(name) >= 2){
    for(i in 2:length(name)){
      q <- bcodeB[, i]
      names(q) <- bcodeB[,1]
      cols <- qualitative_hcl(length(unique(bcodeB[,i])), palette="Dynamic")
      vals <- unique(bcodeB[,i])
      cMap <- chmNewColorMap(vals, cols)
      if (startsWith(name[i], "META_")){
        metaName <- substr(name[i], 6, nchar(name[i]))
        hm <- chmAddMetaData(hm, 'col', metaName, q)
      }
      else if (startsWith(name[i], "AUTO_PLATE")){ # AUTO.PLATE must be specified before AUTO.WELL!
        if (length(unique(q)) > 1){
          tempName <- substr(name[i], 6, nchar(name[i]))
          col <- chmNewCovariate(tempName, q, type='discrete', cMap)
          hm <- chmAddCovariateBar(hm, 'column', col, thickness=as.integer(20))
        }
      }
      else if(startsWith(name[i], "AUTO_WELL")){
        tempName <- substr(name[i], 6, nchar(name[i]))
        col <- chmNewCovariate(tempName, q, type='discrete', cMap)
        hm <- chmAddCovariateBar(hm, 'column', col, thickness=as.integer(20))
      }
      else{
        col <- chmNewCovariate(name[i], q, type='discrete', cMap )
        hm <- chmAddCovariateBar(hm, 'column', col, thickness=as.integer(20))
      }
    }
  }
 
  # BarcodeA / Targets / Covariates processing 
  if (bcodeAin != ""){
    bcodeA <- read.table(text=toString(bcodeAin), sep='\t', comment.char='&', header=T, row.names=1, na.strings=c()) 
    name <- names(bcodeA)
    
  }
  else{
    name <-names(BarcodeA)[2:ncol(BarcodeA)]
    bcodeA <- BarcodeA[, 2:ncol(BarcodeA)]
  }
  if (length(name) >= 2){
    for(i in 2:length(name)){
      q <- bcodeA[,i]
      cols <- qualitative_hcl(length(unique(bcodeA[,i])), palette="Dynamic")
      vals <- unique(bcodeA[,i])
      cMap <- chmNewColorMap(vals, cols)
      if (startsWith(name[i], "META_")){
        names(q) <- bcodeA[,1]
        metaName <- substr(name[i], 6, nchar(name[i]))
        hm <- chmAddMetaData(hm, 'row', metaName, q)
      }
      else if(startsWith(name[i], "UniprotID")){
        names(q) <- bcodeA[,1]
        hm <- chmAddMetaData(hm, 'row', "bio.protein.uniprotid", q)
        
      }
      else{
        names(q) <- bcodeA[, 1]
        row <- chmNewCovariate(name[i], q, type='discrete', cMap)
        hm <- chmAddCovariateBar(hm, 'row', row, thickness=as.integer(20))
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

