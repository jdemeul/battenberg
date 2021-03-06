% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/haplotype.R
\name{GetChromosomeBAFs}
\alias{GetChromosomeBAFs}
\title{Morphs phased SNPs from WGS input into haplotype blocks}
\usage{
GetChromosomeBAFs(chrom, SNP_file, haplotypeFile, samplename, outfile,
  chr_names, minCounts = 1)
}
\arguments{
\item{chrom}{The chromosome number for which this function is called.}

\item{SNP_file}{File containing allele counts for each SNP location.}

\item{haplotypeFile}{File containing impute phasing output.}

\item{samplename}{Name of the sample (used in header of output file).}

\item{outfile}{Full path to where the output will be written.}

\item{chr_names}{Names of all allowed chromosomes as a Vector.}

\item{minCounts}{An integer describing the minimum number of reads covering this position to be included in the output.}
}
\description{
Morphs phased SNPs from WGS input into haplotype blocks
}
\author{
dw9
}
