# -- Function: OGSA for ranking fusions or junctions within the data###
## First version Nov 14,2014
## This function ranks samples based on the number of outliers present in tumor samples, and then by median of expression in tumors
## Add Fisher test to compare outlier calls in tumors and normals. December 17, 2014
## Add FDR correction as a parameter, April 17, 2014.  default, no correction.
# Otherwise corection==name of correction method, i.e. "holm", "hochberg", "hommel", "bonferroni", "BH", "BY", "fdr", "none"
# if getting outlier calls for output, outliers=T

dotheogsa <- function(Sample.data, PHENO, offsets = 0.001, Fisher = FALSE, correction = NA, outliers = FALSE)
## PHENO should have 'Normal' or 'Tumor' calls where Tumor ==1, Normal ==0, and names of each sample associated
{
    ## Define tumors and normals

    ### run outlier analysis for true distribution of tumors and normals

    if (Fisher == TRUE) {
        ## Initialize a matrix so program will call outliers in normals
        Sample.data.normals <- Sample.data[, PHENO == 0]
        no.of.normals <- sum(PHENO == 0)
        no.of.tumors <- sum(PHENO == 1)
        # repeat the normal samples so they will be tested as if they are a set of tumors
        Sample.data.normals <- cbind(Sample.data.normals, Sample.data.normals)
        PHENO.N <- PHENO[PHENO == 0]
        PHENO.N[PHENO.N == 0] <- 1
        PHENO2 <- c(PHENO[PHENO == 0], PHENO.N)
        dataExprs2 <- list(list(Sample.data.normals, PHENO2))
    }

    PHENO <- t(data.frame(PHENO))

    dataExprs <- list(list(Sample.data, PHENO))


    ## get expression of junction in tumors
    Sample.data.tumor <- Sample.data[, PHENO == 1] ## subset to expression in tumors only
    SampleTotals <- apply(Sample.data.tumor, 1, median) ## median of tumor expression

    ## Rank first by number of outliers identified.  Then if there are samples with the same outlier, order by the median of tumor expression

    ## smallest to largest, copa10 (underexpression in tumors)
    ## now do the outlier ranking with tail='left' for if tumor is less than normal
    outRankExprs1 <- outCallRank(dataExprs, names = c("Expr"), tail = "left", corr = TRUE, offsets = offsets)$Expr
    ### get number of outliers in the tumor group
    Num_UE_Outliers <- apply(outRankExprs1, 1, sum)
    SampleTotals1 <- order(SampleTotals, decreasing = TRUE)
    ## ranks first by # of outliers, then by smaller level of tumor expression
    UE_Rank <- order(Num_UE_Outliers, SampleTotals1, decreasing = TRUE)

    if (Fisher == TRUE) {
        ## Calculate outliers in normal tissue
        outRankExprs1.normals <- outCallRank(dataExprs2,
            names = c("Expr"), tail = "left",
            corr = TRUE, offsets = offsets
        )$Expr
        outRankNormal1 <- apply(outRankExprs1.normals, 1, sum)

        ## Perform Fisher's exact test
        FisherP1 <- matrix(NA,
            nrow = nrow(Sample.data), ncol = 1,
            dimnames = list(c(row.names(Sample.data)), "FisherP1")
        )

        for (i in seq_len(nrow(Sample.data))) {
            ## Make contingency tables
            test <- matrix(
                c(
                    outRankNormal1[i], no.of.normals - outRankNormal1[i],
                    Num_UE_Outliers[i], no.of.tumors - Num_UE_Outliers[i]
                ),
                nrow = 2, ncol = 2, dimnames = list(c("outliers", "rest"), c("Normal", "Tumor"))
            )
            ## Get p-value from fisher test.  Will do two sided test
            FisherP1[i] <- fisher.test(test, alternative = "two.sided")$p.value
        }
    }

    ###### largest to smallest, copa90 (overexpression in tumors)#####################
    outRankExprs2 <- outCallRank(dataExprs,
        names = c("Expr"), tail = "right",
        corr = TRUE, offsets = offsets
    )$Expr
    Num_OE_Outliers <- apply(outRankExprs2, 1, sum)
    OE_Rank <- order(Num_OE_Outliers, SampleTotals, decreasing = TRUE)


    if (Fisher == TRUE) {
        ## Calculate outliers in normal tissue
        outRankExprs2.normals <- outCallRank(dataExprs2,
            names = c("Expr"), tail = "right",
            corr = TRUE, offsets = offsets
        )$Expr
        outRankNormal2 <- apply(outRankExprs2.normals, 1, sum)

        ## Perform Fisher's exact test
        FisherP2 <- matrix(NA,
            nrow = nrow(Sample.data), ncol = 1,
            dimnames = list(c(row.names(Sample.data)), "FisherP2")
        )

        for (i in seq_len(nrow(Sample.data))) {
            ## Make contingency tables
            test <- matrix(
                c(
                    outRankNormal2[i], no.of.normals - outRankNormal2[i],
                    Num_OE_Outliers[i], no.of.tumors - Num_OE_Outliers[i]
                ),
                nrow = 2, ncol = 2, dimnames = list(c("outliers", "rest"), c("Normal", "Tumor"))
            )
            ## Get p-value from fisher test.  Will do two sided test
            FisherP2[i] <- fisher.test(test, alternative = "two.sided")$p.value
        }
    }

    ## output data for the function!
    if (outliers == FALSE) {
        if (Fisher == TRUE) {
            ## add FDR correction
            if (!is.na(correction)) {
                FisherP1 <- p.adjust(FisherP1, method = correction)
                FisherP2 <- p.adjust(FisherP2, method = correction)
            }
            RankingData_UE <- cbind(Num_UE_Outliers, UE_Rank, FisherP1)
            RankingData_OE <- cbind(Num_OE_Outliers, OE_Rank, FisherP2)
            RankingData_UE <- as.data.frame(RankingData_UE)
            RankingData_OE <- as.data.frame(RankingData_OE)
            RankingData_UE <- RankingData_UE[RankingData_UE$UE_Rank, ]
            RankingData_OE <- RankingData_OE[RankingData_OE$OE_Rank, ]
            RankingData_UE$UE_Rank <- c(seq_len(nrow(RankingData_UE)))
            RankingData_OE$OE_Rank <- c(seq_len(nrow(RankingData_OE)))
            RankingData <- merge(RankingData_UE, RankingData_OE, by = "row.names", all = TRUE)
            rownames(RankingData) <- RankingData$Row.names
            RankingData <- subset(RankingData, select = -Row.names)
            return(RankingData)
        } else {
            RankingData <- cbind(Num_UE_Outliers, UE_Rank, Num_OE_Outliers, OE_Rank)
            return(RankingData)
        }
    } else {
        OutlierCalls <- list("TumorUnderExpression" = outRankExprs1, "TumorOverExpression" = outRankExprs2)
        return(OutlierCalls)
    }
}
