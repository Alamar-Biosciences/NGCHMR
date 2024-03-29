library(future)
library(promises)
library(NGCHM)
library(NGCHMSupportFiles)
library(mime)
library(xml2)
library(colorspace)
options(future.rng.onMisuse="ignore")
shaidy <- Sys.getenv("SHAIDYMAPGEN")
# Capture version and date information
verFile <- ""
if (file.exists(".git/refs/heads/main")){
  verFile <- ".git/refs/heads/main"
}else if(file.exists("main")){
  verFile <- "main"
}else if(file.exists("/workingDir/main")){
  verFile <- "/workingDir/main"
}

#* To check the health of the API server, do nothing -> Returns Ok
#*
#* @get /healthCheck
#* @serializer contentType list(type="text/plain; charset=UTF-8")
function(res){
  future({
    res$status <- 200
    return("Ok")
    })
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
#* @param data:file XML input file
#* @param method Normalization Method [IC, raw] 
#* @param keepControls
#* @param bcodeB:file BarcodeB file
#* @param bcodeA:file BarcodeA file
#* @param IPC
#* @param NC
#* @param rowOrder Custom Row order
#* @param colOrder Custom Column order
#* @param rowDist Distance metric for row clustering (ignored if rowOrder is specified) [euclidean, maximum, manhattan, canberra, binary, minkowski, correlation, cosine]
#* @param colDist Distance metric for column clustering (ignored if colOrder is specified[euclidean, maximum, manhattan, canberra, binary, minkowski, correlation, cosine]
#* @param rowAgglom Row agglomeration method (ignored if rowOrder is specified) [average, complete, ward.D, ward.D2, single, mcquitty, median, centroid]
#* @param colAgglom Column agglomieration method (ignored if colOrder is specified) [average, complete, ward.D, ward.D2, single, mcquitty, median, centroid]
#* @serializer contentType list(type="application/octet-stream")
#* @post /ngchm
ngchm <- function(data, method="IC", keepControls=FALSE, bcodeB="", bcodeA="", 
                  IPC=c('InterPlateControl'), NC=c('NegativeControl'), IC=c('mCherry'),
                  rowDist='euclidean', colDist='euclidean', rowAgglom='average', colAgglom='average', rowOrder="", colOrder=""){
  future_promise({
  Sys.setenv(SHAIDYMAPGEN=shaidy)
  root <- xml_root(read_xml(toString(data)))

  # Read BarcodeAs
  x <- NULL; y <- NULL;
  for (barcodeA in xml_find_all(root, ".//BarcodeA")){
    for (bcode_A in xml_find_all(barcodeA, ".//Barcode")){
      x <- if(is.null(x)) xml_attrs(bcode_A) else rbind(x, xml_attrs(bcode_A))
      y <- if(is.null(y)) xml_text(bcode_A) else  rbind(y, xml_text(bcode_A))
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
    for (bcode_B in xml_find_all(barcodeB, ".//Barcode")){
      if (keepControls || (!grepl(paste(NC, collapse="|"), xml_text(bcode_B)) && !grepl(paste(IPC, collapse="|"), xml_text(bcode_B)))){
        x <- if(is.null(x)) xml_attrs(bcode_B) else rbind(x, xml_attrs(bcode_B))
        y <- if(is.null(y)) xml_text(bcode_B)  else rbind(y, xml_text(bcode_B))
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
    for (combined in xml_find_all(sample, ".//Replicate")){ # "Combined" - Sample, or "Replicate"
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
  hm <- NULL
  if(rowOrder == "" && colOrder != ""){
    hm <- chmNew('temp', as.matrix(storage), colOrder=colOrder, rowDist=rowDist, rowAgglom=rowAgglom)
  }else if (rowOrder != "" && colOrder == ""){
    hm <- chmNew('temp', as.matrix(storage), rowOrder=rowOrder, colDist=colDist, colAgglom=colAgglom)
  }else if (rowOrder != "" && colOrder != ""){
    hm <- chmNew('temp', as.matrix(storage), rowOrder=rowOrder, colOrder=colOrder)
  }else{
    hm <- chmNew('temp', as.matrix(storage), rowDist=rowDist, colDist=colDist, rowAgglom=rowAgglom, colAgglom=colAgglom)
  }

  # BarcodeB / Targets / Covariates processing 
  if (bcodeB != ""){
    bcode_B <- read.table(text=toString(bcodeB), sep='\t', comment.char='&', header=T, row.names=1, na.strings=c())
    name <- colnames(bcode_B)
  }
  else{
    name <-names(BarcodeB)[2:ncol(BarcodeB)]
    bcode_B <- BarcodeB[, 2:ncol(BarcodeB)]
  }
  if (length(name) >= 2){
    for(i in 2:length(name)){
      q <- bcode_B[, i]
      names(q) <- make.unique(bcode_B[,1])
      cols <- qualitative_hcl(length(unique(bcode_B[,i])), palette="Dynamic")
      vals <- unique(bcode_B[,i])
      cMap <- chmNewColorMap(vals, cols)
      if (startsWith(name[i], "META_")){
        metaName <- substr(name[i], 6, nchar(name[i]))
        hm <- chmAddMetaData(hm, 'col', metaName, q)
      } else if (startsWith(name[i], "AUTO_PLATE")){ # AUTO.PLATE must be specified before AUTO.WELL!
        if (length(unique(q)) > 1){
          tempName <- substr(name[i], 6, nchar(name[i]))
          col <- chmNewCovariate(tempName, q, type='discrete', cMap)
          hm <- chmAddCovariateBar(hm, 'column', col, thickness=as.integer(20))
        }
      } else if(startsWith(name[i], "AUTO_WELL")){
        tempName <- substr(name[i], 6, nchar(name[i]))
        col <- chmNewCovariate(tempName, q, type='discrete', cMap)
        hm <- chmAddCovariateBar(hm, 'column', col, thickness=as.integer(20))
      } else{
        col <- chmNewCovariate(name[i], q, type='discrete', cMap )
        hm <- chmAddCovariateBar(hm, 'column', col, thickness=as.integer(20))
      }
    }
  }
 
  # BarcodeA / Targets / Covariates processing 
  if (bcodeA != ""){
    bcode_A <- read.table(text=toString(bcodeA), sep='\t', comment.char='&', header=T, row.names=1, na.strings=c()) 
    name <- names(bcode_A)
    
  }
  else{
    name <-names(BarcodeA)[2:ncol(BarcodeA)]
    bcode_A <- BarcodeA[, 2:ncol(BarcodeA)]
  }
  if (length(name) >= 2){
    for(i in 2:length(name)){
      q <- bcode_A[,i]
      cols <- qualitative_hcl(length(unique(bcode_A[,i])), palette="Dynamic")
      vals <- unique(bcode_A[,i])
      cMap <- chmNewColorMap(vals, cols)
      if (startsWith(name[i], "META_")){
        names(q) <- bcode_A[,1]
        metaName <- substr(name[i], 6, nchar(name[i]))
        hm <- chmAddMetaData(hm, 'row', metaName, q)
      }
      else if(startsWith(name[i], "UniprotID")){
        names(q) <- bcode_A[,1]
        hm <- chmAddMetaData(hm, 'row', "bio.protein.uniprotid", q)
        
      }
      else{
        names(q) <- bcode_A[, 1]
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

