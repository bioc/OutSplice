test_that("outsplice function runs and the number of outliers at example ECM1 junction is correct", {
    junction <- system.file("extdata", "HNSC_junctions.txt.gz", package = "OutSplice")
    gene_expr <- system.file("extdata", "HNSC_genes_normalized.txt.gz", package = "OutSplice")
    rawcounts <- system.file("extdata", "Total_Rawcounts.txt", package = "OutSplice")
    sample_labels <- system.file("extdata", "HNSC_pheno_table.txt", package = "OutSplice")
    dir <- paste0(tempdir(), "/")
    results <- outspliceAnalysis(junction, gene_expr, rawcounts, sample_labels, saveOutput = TRUE, output_file_prefix = "outsplice_unit_test", dir = dir, filterSex = TRUE, annotation = "org.Hs.eg.db", TxDb = "TxDb.Hsapiens.UCSC.hg19.knownGene", offsets_value = 0.00001, correction_setting = "fdr", p_value = 0.05)
    expect_no_error(results)
    expect_equal(unname(unlist(results$FisherAnalyses["chr1:150483674-150483933", "Num_OE_Outliers"])), 28)
})
