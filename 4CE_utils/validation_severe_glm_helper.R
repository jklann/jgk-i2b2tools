##helper functions for computing classification performance
###author: Hossein Estiri -- hestiri@mgh.harvard.edu


metrix <- function(datval,#data on which validation will be computed
                   model,#model!
                   label.col,#column number with labels
                   note,#modeli description
                   op,#cutoff for ppv.npv
                   phenx="phenotype",
                   topn,#number of top features used
                   class="binary"#binary or continous prediction
                   ){
  
  if (class == "binary"){
  datval[c("N","Y")] <- data.frame(predict(model, newdata = datval, type = "prob"))
  # calculating the AUC ROC
  roc_obj1 <- roc(datval[,label.col], datval$Y)
  datval$actual <- ifelse(datval[,label.col] == "Y", 1,0)
  } else if (class !="binary"){
    datval[c("Y")] <- data.frame(predict(model, newdata = datval))
    # calculating the AUC ROC
    roc_obj1 <- roc(datval[,label.col], datval$Y)
    datval$actual <- ifelse(datval[,label.col] == "Y", 1,0)
  }
  ROC <- data.frame(paste0(note))
  colnames(ROC) <- c("model")
  ROC$roc <- as.numeric(roc_obj1$auc)
  sensificities1 <- data.frame(cbind(roc_obj1$sensitivities,roc_obj1$specificities,roc_obj1$thresholds))
  colnames(sensificities1) <- c("sensitivities","specificities","threshold")
  sensificities1$J <- sensificities1$sensitivities+sensificities1$specificities-1
  ROC$J.specificity <- as.numeric(sensificities1[sensificities1$J == as.numeric(max(sensificities1$J)), "specificities"][1])
  ROC$J.sensitivity <- as.numeric(sensificities1[sensificities1$J == as.numeric(max(sensificities1$J)), "sensitivities"][1])###
  ROC$thresholdj <- as.numeric(sensificities1[sensificities1$J == as.numeric(max(sensificities1$J)), "threshold"][1])
  ROC$ppv.j <- ppv(datval$actual, datval$Y, cutoff = ROC$thresholdj)
  ROC$npv.j <- InformationValue::npv(datval$actual, datval$Y, threshold = ROC$thresholdj)
  ROC$ROC <- op
  ROC$ppv.cutoff <- ppv(datval$actual, datval$Y, cutoff = op)
  ROC$npv.cutoff <- InformationValue::npv(datval$actual, datval$Y, threshold = op)
  
  #### calculating ROC and PRROC using another package
  roc2 <- PRROC::roc.curve(datval[(datval[,label.col] == "Y"),"Y"], 
                           datval[(datval[,label.col] == "N"),"Y"])
  
  # PR 
  pr <- PRROC::pr.curve(datval[(datval[,label.col] == "Y"),"Y"], 
                        datval[(datval[,label.col] == "N"),"Y"])
  
  ROC$roc2 <- as.numeric(roc2$auc)
  ROC$pr.integral <- as.numeric(pr$auc.integral)
  ROC$pr.davis.goadrich <- as.numeric(pr$auc.davis.goadrich)
  ROC$phenx <- phenx
  ROC$topn <- topn
  
  return(ROC)
}


