
#' Helper function to adjust the BAF segmented values. By default the segmentation
#' takes the mean BAFphased for each segment, but that doesn't work very well with
#' outliers (i.e. badly phased regions). This function is then called to adjust
#' the segmented BAF. By default this now takes the median
#' @param baf_chrom A data frame with columns BAFphased and BAFseg. BAFseg will be overwritten.
#' @return A data frame with columns BAFphased and BAFseg.
#' @author sd11
#' @noRd
adjustSegmValues = function(baf_chrom) {
  segs = rle(baf_chrom$BAFseg)
  for (i in 1:length(segs$lengths)) {
    end = cumsum(segs$lengths[1:i])
    end = end[length(end)]
    start = (end-segs$lengths[i]) + 1 # segs$lengths contains end points
    # baf_chrom$bafmean[start:end] = mean(baf_chrom$BAFphased[start:end])
    baf_chrom$BAFseg[start:end] = median(baf_chrom$BAFphased[start:end])
    # This needs the ASCAT version of PCF
    # datwins = madWins(baf_chrom$BAFphased[start:end], 2.5, 25)$ywin
    # baf_chrom$madwins_mean[start:end] = mean(datwins)
    # baf_chrom$madwins_median[start:end] = median(datwins)
  }
  return(baf_chrom)
}


#' Segment the haplotyped and phased data using fastPCF.
#' 
#' This function performs segmentation. This is done in two steps. First a segmentation step
#' that aims to find short segments. These are used to find haplotype blocks that have been
#' switched. These blocks are switched into the correct order first after which the second
#' segmentation step is performed. This second step aims to segment the data that will go into
#' fit.copy.number. This function produces a BAF segmented file with 5 columns: chromosome, position,
#' original BAF, switched BAF and BAF segment. The BAF segment column should be used subsequently
#' @param samplename Name of the sample, which is used to name output figures
#' @param inputfile String that points to the output from the \code{combine.baf.files} function. This contains the phased SNPs with their BAF values
#' @param outputfile String where the segmentation output will be written
#' @param gamma The gamma parameter controls the size of the penalty of starting a new segment during segmentation. It is therefore the key parameter for controlling the number of segments (Default: 10)
#' @param kmin Kmin represents the minimum number of probes/SNPs that a segment should consist of (Default: 3)
#' @param phasegamma Gamma parameter used when correcting phasing mistakes (Default: 3)
#' @param phasekmin Kmin parameter used when correcting phasing mistakes (Default: 3)
#' @param calc_seg_baf_option Various options to recalculate the BAF of a segment. Options are: 1 - median, 2 - mean. (Default: 1)
#' @author dw9
#' @export
segment.baf.phased = function(samplename, inputfile, outputfile, gamma=10, phasegamma=3, kmin=3, phasekmin=3, calc_seg_baf_option=1) {
  BAFraw = read.table(inputfile,sep="\t",header=T, stringsAsFactors=F)
  
  BAFoutput = NULL
  for (chr in unique(BAFraw[,1])) {
    BAFrawchr = BAFraw[BAFraw[,1]==chr,c(2,3)]
    BAFrawchr = BAFrawchr[!is.na(BAFrawchr[,2]),]
    
    BAF = BAFrawchr[,2]
    pos = BAFrawchr[,1]
    names(BAF) = rownames(BAFrawchr)
    names(pos) = rownames(BAFrawchr)
    
    sdev <- getMad(ifelse(BAF<0.5,BAF,1-BAF),k=25)
    # Standard deviation is not defined for a single value
    if (is.na(sdev)) {
      sdev = 0
    }
    #DCW 250314
    #for cell lines, sdev goes to zero in regions of LOH, which causes problems.
    #0.09 is around the value expected for a binomial distribution around 0.5 with depth 30
    if(sdev<0.09){
      sdev = 0.09
    }
    
    print(paste("BAFlen=",length(BAF),sep=""))
    if(length(BAF)<50){
      BAFsegm = rep(mean(BAF),length(BAF))
    }else{
      res= selectFastPcf(BAF,phasekmin,phasegamma*sdev,T)
      BAFsegm = res$yhat
    }
    
    png(filename = paste(samplename,"_RAFseg_chr",chr,".png",sep=""), width = 2000, height = 1000, res = 200)
    create.segmented.plot(chrom.position=pos/1000000, 
                          points.red=BAF, 
                          points.green=BAFsegm, 
                          x.min=min(pos)/1000000, 
                          x.max=max(pos)/1000000, 
                          title=paste(samplename,", chromosome ", chr, sep=""), 
                          xlab="Position (Mb)", 
                          ylab="BAF (phased)")
    dev.off()
    
    BAFphased = ifelse(BAFsegm>0.5,BAF,1-BAF)
    
    if(length(BAFphased)<50){
      BAFphseg = rep(mean(BAFphased),length(BAFphased))
    }else{
      res = selectFastPcf(BAFphased,kmin,gamma*sdev,T)
      BAFphseg = res$yhat
    }
    
    # Recalculate the BAF of each segment, if required
    if (calc_seg_baf_option==1) {
      # Adjust the segment BAF to not take the mean as that is sensitive to improperly phased segments
      BAFphseg = adjustSegmValues(data.frame(BAFphased=BAFphased, BAFseg=BAFphseg))$BAFseg
    } else if (calc_seg_baf_option==2) {
      # Don't do anything, the BAF is already the mean
    } else {
      warning("Supplied calc_seg_baf_option to segment.baf.phased not valid, using mean BAF by default")
    }
    
    png(filename = paste(samplename,"_segment_chr",chr,".png",sep=""), width = 2000, height = 1000, res = 200)
    create.baf.plot(chrom.position=pos/1000000, 
                    points.red.blue=BAF, 
                    plot.red=BAFsegm>0.5,
                    points.darkred=BAFphseg, 
                    points.darkblue=1-BAFphseg, 
                    x.min=min(pos)/1000000, 
                    x.max=max(pos)/1000000, 
                    title=paste(samplename,", chromosome ", chr, sep=""), 
                    xlab="Position (Mb)", 
                    ylab="BAF (phased)")
    dev.off()
    
    BAFphased = ifelse(BAFsegm>0.5, BAF, 1-BAF)
    BAFoutputchr = data.frame(Chromosome=rep(chr, length(BAFphseg)), Position=pos, BAF=BAF, BAFphased=BAFphased, BAFseg=BAFphseg)
    BAFoutput = rbind(BAFoutput, BAFoutputchr)
  }
  colnames(BAFoutput) = c("Chromosome","Position","BAF","BAFphased","BAFseg")
  write.table(BAFoutput, outputfile, sep="\t", row.names=F, col.names=T, quote=F)
}

#' Segment BAF with the inclusion of structural variant breakpoints
#' 
#' This function takes the SV breakpoints as initial segments and runs PCF on each
#' of those independently. The SVs must be supplied as a simple data.frame with columns
#' chromosome and position
#' @param samplename Name of the sample, which is used to name output figures
#' @param inputfile String that points to the output from the \code{combine.baf.files} function. This contains the phased SNPs with their BAF values
#' @param outputfile String where the segmentation output will be written
#' @param svs Data.frame with chromosome and position columns
#' @param gamma The gamma parameter controls the size of the penalty of starting a new segment during segmentation. It is therefore the key parameter for controlling the number of segments (Default 10)
#' @param kmin Kmin represents the minimum number of probes/SNPs that a segment should consist of (Default 3)
#' @param phasegamma Gamma parameter used when correcting phasing mistakes (Default 3)
#' @param phasekmin Kmin parameter used when correcting phasing mistakes (Default 3)
#' @param no_segmentation Do not perform segmentation. This step will switch the haplotype blocks, but then just takes the mean BAFphased as BAFsegm
#' @param calc_seg_baf_option Various options to recalculate the BAF of a segment. Options are: 1 - median, 2 - mean. (Default: 1)
#' @author sd11
#' @export
segment.baf.phased.sv = function(samplename, inputfile, outputfile, svs, gamma=10, phasegamma=3, kmin=3, phasekmin=3, no_segmentation=F, calc_seg_baf_option=1) {
  # Function that takes SNPs that belong to a single segment and looks for big holes between
  # each pair of SNPs. If there is a big hole it will add another breakpoint to the breakpoints data.frame
  addin_bigholes = function(breakpoints, positions, chrom, startpos, maxsnpdist) {
    # If there is a big hole (i.e. centromere), add it in as a separate set of breakpoints
    
    # Get the chromosome coordinate right before a big hole
    bigholes = which(diff(positions)>=maxsnpdist)
    if (length(bigholes) > 0) {
      for (endindex in bigholes) {
        breakpoints = rbind(breakpoints, 
                            data.frame(chrom=chrom, start=startpos, end=positions[endindex]))
        startpos = positions[endindex+1]
      }
    }
    return(list(breakpoints=breakpoints, startpos=startpos))
  }
  
  # Helper function that creates segment breakpoints from SV calls
  # @param svs_chrom Structural variant breakpoints for a single chromosome
  # @param BAFrawchr Raw BAF values of germline heterozygous SNPs on a single chromosome
  # @param addin_bigholes Flag whether bog holes in data are to be added as breakpoints
  # @return A data.frame with chrom, start and end columns
  # @author sd11
  svs_to_presegment_breakpoints = function(chrom, svs_chrom, BAFrawchr, addin_bigholes) {
    maxsnpdist = 3000000
    
    svs_breakpoints = svs_chrom$position
    
    # If there are no SVs we cannot insert any breakpoints
    if (length(svs_breakpoints) > 0) {
      breakpoints = data.frame()
      
      # check which comes first, the breakpoint or the first SNP
      if (BAFrawchr$Position[1] < svs_breakpoints[1]) {
        startpos = BAFrawchr$Position[1]
        startfromsv = 1 # We're starting from SNP data, so the first SV should be added first
      } else {
        startpos = svs_breakpoints[1]
        startfromsv = 2 # We've just added the first SV, don't use it again
      }
      
      for (svposition in svs_breakpoints[startfromsv:length(svs_breakpoints)]) {
        selectedsnps = BAFrawchr$Position >= startpos & BAFrawchr$Position <= svposition
        if (sum(selectedsnps, na.rm=T) > 0) {
          
          if (addin_bigholes) {
            # If there is a big hole (i.e. centromere), add it in as a separate set of breakpoints
            res = addin_bigholes(breakpoints, BAFrawchr$Position[selectedsnps], chrom, startpos, maxsnpdist)
            breakpoints = res$breakpoints
            startpos = res$startpos
          }
          
          endindex = max(which(selectedsnps))
          breakpoints = rbind(breakpoints, data.frame(chrom=chrom, start=startpos, end=BAFrawchr$Position[endindex]))
          # Previous SV is the new starting point for the next segment
          startpos = BAFrawchr$Position[endindex + 1]
        }
      }
      
      # Add the remainder of the chromosome, if available
      if (BAFrawchr$Position[nrow(BAFrawchr)] > svs_breakpoints[length(svs_breakpoints)]) {
        endindex = nrow(BAFrawchr)
        breakpoints = rbind(breakpoints, data.frame(chrom=chrom, start=startpos, end=BAFrawchr$Position[endindex]))
      }
    } else {
      # There are no SVs, so create one big segment
      print("No SVs")
      startpos = BAFrawchr$Position[1]
      breakpoints = data.frame()
      
      if (addin_bigholes) {
        # If there is a big hole (i.e. centromere), add it in as a separate set of breakpoints
        res = addin_bigholes(breakpoints, BAFrawchr$Position, chrom, startpos, maxsnpdist=maxsnpdist)
        breakpoints = res$breakpoints
        startpos = res$startpos
      }
      
      breakpoints = rbind(breakpoints, data.frame(chrom=chrom, start=startpos, end=BAFrawchr$Position[nrow(BAFrawchr)]))
    }
    return(breakpoints)
  }
  
  # Run PCF on presegmented data
  # @param BAFrawchr Raw BAF for this chromosome
  # @param presegment_chrom_start
  # @param presegment_chrom_end
  # @param phasekmin
  # @param phasegamma
  # @param kmin
  # @param gamma
  # @param no_segmentation Do not perform segmentation. This step will switch the haplotype blocks, but then just takes the mean BAFphased as BAFsegm
  # @return A data.frame with columns Chromosome,Position,BAF,BAFphased,BAFseg
  run_pcf = function(BAFrawchr, presegment_chrom_start, presegment_chrom_end, phasekmin, phasegamma, kmin, gamma, no_segmentation=F) {
    row.indices = which(BAFrawchr$Position >= presegment_chrom_start & 
                          BAFrawchr$Position <= presegment_chrom_end)
    
    BAF = BAFrawchr[row.indices,2]
    pos = BAFrawchr[row.indices,1]
    # names(BAF) = rownames(BAFrawchr[row.indices])
    # names(pos) = rownames(BAFrawchr[row.indices])
    
    sdev <- getMad(ifelse(BAF<0.5,BAF,1-BAF),k=25)
    # Standard deviation is not defined for a single value
    if (is.na(sdev)) {
      sdev = 0
    }
    #DCW 250314
    #for cell lines, sdev goes to zero in regions of LOH, which causes problems.
    #0.09 is around the value expected for a binomial distribution around 0.5 with depth 30
    if(sdev<0.09){
      sdev = 0.09
    }
    
    print(paste("BAFlen=",length(BAF),sep=""))
    if(length(BAF)<50){
      BAFsegm = rep(mean(BAF),length(BAF))
    }else{
      res = selectFastPcf(BAF,phasekmin,phasegamma*sdev,T)
      BAFsegm = res$yhat
    }
    
    BAFphased = ifelse(BAFsegm>0.5,BAF,1-BAF)
    
    if(length(BAFphased)<50 | no_segmentation){
      BAFphseg = rep(mean(BAFphased),length(BAFphased))
    }else{
      res = selectFastPcf(BAFphased,kmin,gamma*sdev,T)
      BAFphseg = res$yhat
    }
    
    if (length(BAF) > 0) {
      # Recalculate the BAF of each segment, if required
      if (calc_seg_baf_option==1) {
        # Adjust the segment BAF to not take the mean as that is sensitive to improperly phased segments
        BAFphseg = adjustSegmValues(data.frame(BAFphased=BAFphased, BAFseg=BAFphseg))$BAFseg
      } else if (calc_seg_baf_option==2) {
        # Don't do anything, the BAF is already the mean
      } else {
        warning("Supplied calc_seg_baf_option to segment.baf.phased.sv not valid, using mean BAF by default")
      }
    }
    
    return(data.frame(Chromosome=rep(chr, length(row.indices)), 
                      Position=BAFrawchr[row.indices,1], 
                      BAF=BAF, 
                      BAFphased=BAFphased, 
                      BAFseg=BAFphseg,
                      tempBAFsegm=BAFsegm)) # Keep track of BAFsegm for the plot below
  }
  
  # bafsegments, breakpoints, kmin, gamma_param, samplename, filename_suffix="jabba_aspcf"
  BAFraw = read.table(inputfile,sep="\t",header=T, stringsAsFactors=F)
  
  BAFoutput = NULL
  for (chr in unique(BAFraw[,1])) {
    print(paste0("Segmenting ", chr))
    BAFrawchr = BAFraw[BAFraw[,1]==chr,c(2,3)]
    # BAFrawchr = bafsegments[bafsegments$Chromosome==chr, c(2,3)]
    BAFrawchr = BAFrawchr[!is.na(BAFrawchr[,2]),]
    svs_chrom = svs[svs$chromosome==chr,]
    
    breakpoints_chrom = svs_to_presegment_breakpoints(chr, svs_chrom, BAFrawchr, addin_bigholes=T)
    BAFoutputchr = NULL
    
    for (r in 1:nrow(breakpoints_chrom)) {
      BAFoutput_preseg = run_pcf(BAFrawchr, breakpoints_chrom$start[r], breakpoints_chrom$end[r], phasekmin, phasegamma, kmin, gamma, no_segmentation)
      BAFoutputchr = rbind(BAFoutputchr, BAFoutput_preseg)
    }
    
    png(filename = paste(samplename,"_RAFseg_chr",chr,".png",sep=""), width = 2000, height = 1000, res = 200)
    create.segmented.plot(chrom.position=BAFoutputchr$Position/1000000, 
                          points.red=BAFoutputchr$BAF, 
                          points.green=BAFoutputchr$tempBAFsegm, 
                          x.min=min(BAFoutputchr$Position)/1000000, 
                          x.max=max(BAFoutputchr$Position)/1000000, 
                          title=paste(samplename,", chromosome ", chr, sep=""), 
                          xlab="Position (Mb)", 
                          ylab="BAF (phased)",
                          svs_pos=svs_chrom$position/1000000)
    dev.off()
    
    png(filename = paste(samplename,"_segment_chr",chr,".png",sep=""), width = 2000, height = 1000, res = 200)
    create.baf.plot(chrom.position=BAFoutputchr$Position/1000000, 
                    points.red.blue=BAFoutputchr$BAF, 
                    plot.red=BAFoutputchr$tempBAFsegm>0.5,
                    points.darkred=BAFoutputchr$BAFseg, 
                    points.darkblue=1-BAFoutputchr$BAFseg, 
                    x.min=min(BAFoutputchr$Position)/1000000, 
                    x.max=max(BAFoutputchr$Position)/1000000, 
                    title=paste(samplename,", chromosome ", chr, sep=""), 
                    xlab="Position (Mb)", 
                    ylab="BAF (phased)",
                    svs_pos=svs_chrom$position/1000000)
    dev.off()
    
    BAFoutputchr$BAFphased = ifelse(BAFoutputchr$tempBAFsegm>0.5, BAFoutputchr$BAF, 1-BAFoutputchr$BAF)
    # Remove the temp BAFsegm values as they are only needed for plotting
    BAFoutput = rbind(BAFoutput, BAFoutputchr[,c(1:5)])
  }
  colnames(BAFoutput) = c("Chromosome","Position","BAF","BAFphased","BAFseg")
  write.table(BAFoutput, outputfile, sep="\t", row.names=F, col.names=T, quote=F)
}
