searchKQ <- function(dataR6, classifInit, pastICL = c(), Kmin=NULL, Kmax=NULL, nbCores=NULL, verbose = TRUE, maxiterVE = NULL, maxiterVEM = NULL){
  #




  os <- Sys.info()["sysname"]
  #os  = "Windows"
  if (is.null(nbCores)) {nbCores <- detectCores(all.tests = FALSE, logical = TRUE) %/% 2}
  #if ((os != 'Windows') &
  #if (os  == "Windows") {nbCores = 1}


  #------
  vKinit = calcVK(classifInit)
  if (length(vKinit) != dataR6$Q) { stop('Length of vKinit incorrect') }
  if (verbose) { print(paste(" ------ Searching the numbers of blocks starting from [",paste(as.character(vKinit),collapse = " "),"] blocks",sep = " "))}


  #----------------------   Initialisation of the algorithm
  niterSearch <- 0;
  ICL.c <- -Inf;
  classifC <- classifInit;
  classifNew <- classifC
  estimNew <- dataR6$estime(classifInit,maxiterVE = maxiterVE, maxiterVEM = maxiterVEM);


  paramNew <- estimNew$paramEstim
  classifNew <- lapply(1:dataR6$Q,
    function(q){
      Z_q = max.col(paramNew$tau[[q]])
      Z_q = match(Z_q, unique(sort(Z_q)))
      names(Z_q) <- dataR6$namesInd[[q]];
      return(Z_q)
      }
    )

  estimNew$paramEstim$Z = classifNew
  ICLNew <- estimNew$ICL
  if (!estimNew$convergence){ICLNewprint = -Inf}else{ ICLNewprint <- ICLNew }

  if (verbose) {
    mess <- paste(round(c(calcVK(classifNew))),collapse = " " )
    mess <- paste("ICL :",round(ICLNewprint,2),". Nb of blocks: [", mess, "]",sep = " ")
    if (!estimNew$convergence){
      mess = paste(mess,". Convergence was not reached here.")
    }
    print(mess)
  }

  vec.ICL = ICLNew
  RES = list()
  RES[[niterSearch + 1]] <- estimNew;

  #----------------------------------------------  ALGORITHM
  while ( (ICLNew > ICL.c) & !(ICLNew %in% pastICL) & (niterSearch < 1000)) {
    #
    niterSearch <- niterSearch + 1;

    #
    ICL.c <- ICLNew
    classifC <- classifNew

    # list of new classif deriving from the splitting of one block or the merging of 2 blocks in clustering classifC
    # (These clusterisations will serve as initisalition of the EM algorithm for models)
    list_classif_init <- sequentialInitialize(classifC ,dataR6,Kmin,Kmax,os);
    L = length(list_classif_init)


    if (os != 'Windows'){
      if (verbose) {
        allEstim <- pbmcapply::pbmclapply(1:L,function(l){estim.c.l <- dataR6$estime(list_classif_init[[l]],maxiterVE = maxiterVE, maxiterVEM = maxiterVEM)},mc.cores = nbCores)
      }else{
        allEstim <- mclapply(1:L,function(l){estim.c.l <- dataR6$estime(list_classif_init[[l]],maxiterVE = maxiterVE, maxiterVEM = maxiterVEM)},mc.cores = nbCores)
      }
    }else{

      cl <- parallel::makeCluster(nbCores)
      parallel::clusterExport(cl, c("dataR6","list_classif_init", "maxiterVE", "maxiterVEM","L"),envir = environment())
      allEstim <- parLapply(cl, 1:L, function(l){estim.c.l <- dataR6$estime(list_classif_init[[l]],maxiterVE = maxiterVE, maxiterVEM = maxiterVEM)})
      stopCluster(cl)
    }



    all_estim <- dataR6$cleanResults(allEstim)
    if (length(all_estim) > 0){ICLNew <- all_estim[[1]]$ICL}else{ICLNew = -Inf} # meilleur ICL
    vec.ICL <- c(vec.ICL,ICLNew)

    if (ICLNew > ICL.c) {

      estimNew <- all_estim[[1]]
      estimNew$paramEstim$Z <- lapply(1:dataR6$Q,function(q){Z_q <- max.col(estimNew$paramEstim$tau[[q]]);
      Z_q = match(Z_q, unique(sort(Z_q)))
      names(Z_q) <- dataR6$namesInd[[q]]; return(Z_q)})

      names(estimNew$paramEstim$Z) = dataR6$namesFG;

      RES[[niterSearch + 1]] <- estimNew;
      paramNew <- estimNew$paramEstim
      classifNew <- paramNew$Z
      if (verbose) {
        mess <- paste(round(c(calcVK(classifNew))),collapse = " " )
        print(paste("ICL :",round(ICLNew,2),". Nb of blocks: [", mess,"]",sep = " "))
      }
    }

  }

  return(RES)
}

###########################"




