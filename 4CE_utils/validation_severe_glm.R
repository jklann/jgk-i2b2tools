# severe -> outcomes for 4CE
###author: Hossein Estiri -- hestiri@mgh.harvard.edu
###this script, models outcomes for selected severity features.

#### BETA VERSION - SITES ARE NOT EXPECTED TO RUN THIS PRESENTLY

# Set your directory!
dir <- "/Users/jeffklann/HMS/Projects/COVID/4CE/severity_validation/R/"

# Setup
Sys.setenv(R_MAX_NUM_DLLS = 999)
options(scipen = 999)
aoi <- "deathoricu"
seed <- 10000
set.seed(seed)
augment <- "OFF" ##keep demographics in the model? 
options(java.parameters = "-Xmx8048m")

####  Install and load the required packages
if (!require("easypackages")) install.packages('easypackages', repos = "http://cran.rstudio.com/")
if (!require("ggthemes")) install.packages('ggthemes', repos = "http://cran.rstudio.com/")
if (!require("scales")) install.packages('scales', repos = "http://cran.rstudio.com/")
if (!require("reshape2")) install.packages('reshape2', repos = "http://cran.rstudio.com/")
if (!require("foreach")) install.packages('foreach', repos = "http://cran.rstudio.com/")
if (!require("doParallel")) install.packages('doParallel', repos = "http://cran.rstudio.com/")
if (!require("recipes")) install.packages('recipes', repos = "http://cran.rstudio.com/")
packages("data.table","devtools","backports","Hmisc","dplyr","DT","ggplot2","gridExtra","arm","scales","plyr",
         "corrplot","caret","pROC","plotROC","PRROC","randomForest","mlbench","ModelMetrics","LiblineaR","glmboost","pls",
         "e1071","mda","foreach","RRF","sparsediscrim","rrlda","fastAdaboost","klaR","import","sdwd",
         "spls","kernlab","ggrepel","PerformanceAnalytics","bnclassify","stepPlr","bnclassify","InformationValue",
         prompt = F)

# load the helper function
source("validation_severe_glm_helper.R")

### 2 data frames are needed:
#### 1- first, a dems table with patient_num, demographic features from patient_dimension, a date column for hospitalization (hospitallization_date), and a label column
### it'll look like this:    patient_num | .. demographic columns .. | hospitallization_date | label (preferably as factor)

#### all patients in dems table are tested positive for COVID
#### the label column captures whether the patient died OR went to ICU, but it can be anything else defined by the 4CE
#### 1- a dbmart file from i2b2 star schema, for the patients in the dems table. Below is an example SQL code pulled through RODBC 

# Load the data
paste(dir,"facts.csv")
dbmart <- read.csv(paste(dir,"facts.csv",sep=''))
dems <- read.csv(paste(dir,"labels.csv",sep=''))

###################### ##################################
uniqpats <- c(as.character(unique(dbmart$patient_num)))
dems$flagafter <- ifelse(dems$patient_num %in% uniqpats,"Y","N")

#preparing the AVR
# aggregating by patient and data and observation
dbmart$start_date <- as.POSIXct(dbmart$start_date, "%Y-%m-%d")

EHR <- dplyr::select(dbmart,patient_num,phenx)###the  correct column name to be inserted
setDT(EHR)
EHR[,row := .I]
EHR$value.var <- 1

# aggregating by unique patients
EHR.agg <- ddply(EHR, ~ phenx,summarise,distinct_patients=length(unique(patient_num)))

EHR.wide <- reshape2::dcast(EHR, patient_num ~ phenx, value.var="value.var", fun.aggregate = length)
EHR.wide <- as.data.frame(EHR.wide)
EHR.wide <- EHR.wide[, !(names(EHR.wide) %in% c("NA"))]
AVR <- EHR.wide
rm(EHR,EHR.wide);gc()

uniqpats <- c(unique(dbmart$patient_num)) 
#remove lowprevalence AVRs
avrs <- c(as.character(subset(EHR.agg$phenx,EHR.agg$distinct_patients > round(length(uniqpats)/500))))##0.025%
AVR <- AVR[, names(AVR) %in% avrs | names(AVR) %in% c("patient_num")]
rm(avrs);gc()
# dbmart <- subset(dbmart,dbmart$patient_num %in% AVR$patient_num)

dems <- subset(dems,dems$patient_num %in% AVR$patient_num)
labeldt <- dplyr::select(dems,patient_num,label)

# 80-20% train-test set partition
    test_ind <- sample(unique(labeldt[,"patient_num"]),
                         round(.2*nrow(labeldt)))

    ###let's identify the test and training sets
    ###we want to split data into train and validation (test) sets
    test_labels <- subset(labeldt,labeldt$patient_num %in% c(test_ind))
    table(test_labels$label)
    train_labels <- subset(labeldt,!(labeldt$patient_num %in% c(test_ind)))
    table(train_labels$label)
    
    if (augment == "ON"){
      dems2 <- dplyr::select(dems,patient_num,age,sex_cd,black,white,hispanic) #demographic variables that will be added to the analysis if augment is ON
      ###add demographics
      train_labels <- merge(train_labels,dems2,by="patient_num")
      test_labels <- merge(test_labels,dems2,by="patient_num")
      
    }
    
    ##now create the test and training data subsets. 
    dat.VAL <- merge(test_labels,AVR,by="patient_num")
    dat.train <- merge(train_labels,AVR,by="patient_num")
    
    #modeling
    print("to the modeling!")
    goldstandard <- "label"
    dat.train[,c("patient_num")] <- NULL
    
    ROCs <- list()
    coeffs <- list()
    ##using caret implementations for experimentation
    ###setup parallel backend
    cores<-detectCores()
    cl <- makeCluster(cores[1]-2) 
    registerDoParallel(cl)
    ###starting prediction and testing
    dat.train$label <- as.factor(dat.train$label) #jgk had to add 
    
    #jgk use cat
    names(dat.train)[names(dat.train) == "phenx"] <- "concept_cd"
    names(dat.train)[names(dat.train) == "cat"] <- "phenx"
    
    train_control <- caret::trainControl(method="cv", number=5,
                                         summaryFunction = twoClassSummary,
                                         classProbs = T,
                                         savePredictions = T)
    
    
    preProc=c("center", "scale")
    
    model <- caret::train(as.formula(paste(goldstandard, "~ .")),
                          data=dat.train
                          , trControl=train_control
                          , method = "glmboost"
                          ,preProc)
    #   
    library(dplyr);library(pROC);library(PRROC)
    ##predicting on validation data and storing the metrics
    ROC <- metrix(datval = dat.VAL,model=model,label.col = which( colnames(dat.VAL)=="label" ),note="selectedFeatures",op=0.5,phenx = aoi,topn = ncol(dat.train)-1)
    ROC$cv_roc <- mean(model$results$ROC)
    ROC$cv_roc_sd <- mean(model$results$ROCSD)

    
    ##roc curve
    (g <- ggplot(model$pred, aes(m=Y, d=factor(obs, levels = c("Y", "N")))) +
        geom_roc(n.cuts=0) + 
        coord_equal() +
        style_roc()+ 
        annotate("text", x=0.75, y=0.25, label=paste("AUC =", round(ROC$roc, 4))))#round((calc_auc(g))$AUC, 4)
    ggsave(filename=paste(dir,"plotROC.png",sep=''))

    coefficients <- data.frame(unlist(coef(model$finalModel, model$bestTune$lambda)))
    colnames(coefficients) <- "value"
    coefficients$features <- rownames(coefficients)
    rownames(coefficients) <- NULL
    coefficients <- subset(coefficients,coefficients$features != "(Intercept)")

    write.csv(ROC,file = paste(dir,"ROC.csv",sep=''))
    write.csv(coefficients,file = paste(dir,"coeffs.csv",sep=''))
    
    ############# PLOT
    ###plotting the coefficients
    coefficients$features <- as.character(coefficients$features)
    
    coefficients$features <- sub('`\\`', '', coefficients$features, fixed = TRUE)
    coefficients$features <- sub('\\``', '', coefficients$features, fixed = TRUE)
    coefficients$value <- exp(coefficients$value*2) ##OR if exp 
    
    
    #for merging readable coefficient names
    # coefficients <- merge(coefficients,severcode,by.x="features",by.y = "concept_cd",all.x = TRUE)
    # coefficients <- subset(coefficients,!(!(coefficients$c_name %in% c("sex_cd","white","black","hispanic"))
    #                                       & coefficients$value <= 1))
    
    
    
    #c_name is the column name for plotting that has actual feature names

    # change features to c_name to use friendly name
    (pl00 <-ggplot(coefficients,aes(x=reorder(features,abs(value)),y=value))+
        geom_point(size=3,alpha=0.9,shape=15)+
        geom_hline(aes(yintercept=1))+
        coord_flip()+
        ggthemes::theme_fivethirtyeight()+
        theme(
          # axis.text.x=element_blank(),
          # axis.ticks.x=element_blank(),
          panel.grid.major.y = element_line(color = "gray",size=0.1),
          # panel.grid.minor.y = element_line(),
          plot.background = element_rect(fill = "white"),
          # legend.position="bottom",
          axis.title = element_text(),
          axis.text = element_text(size=10),
          # panel.background = element_rect(color = "gray"),
          strip.text = element_text(face="bold"),
          strip.text.x = element_text(face="bold"),
          strip.text.y = element_text(face="bold")#,
          # strip.background = element_rect(colour="black", fill="NA")
        )+ 
        labs(x="",y= "odds ratio",
             title="important risk factors for death/icu after COVID-19 hospitalization",
             caption = ""))
    
    
    
    ggsave(filename=paste0(paste(dir,"riskfactors.png",sep='')), pl00, dpi = 300, width = 8, height = 6)
    write.csv(coefficients,file=paste0(paste(dir,"risk_factors.csv",sep='')))
    


