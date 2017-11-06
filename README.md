# RADseq_pipeline
I describe here the pipeline I used to process RADseq data from non-model organisms without a reference genome. The pipeline starts with fastq files returned from sequencing center and finishes with a list of loci that pass various filters and SNP variants in VCF format.

## install stacks 1.32
download stacks from http://catchenlab.life.illinois.edu/stacks/, where also hosts good tutorial and information of the stacks pipeline

```
tar xzvf stacks-1.32.tar.gz
cd stacks-1.32
./configure --prefix=/u/home/z/zhen/bin/stacks1.32
make
make install
```
note this is for stacks 1.32, there are many good updates using later versions of stacks, which may require changes in the scripts

## Step 1: check data quality using fastqc
```
zcat TSKR012_S13_L003_R1_001.fastq.gz | fastqc stdin
```

## Optional Step 2 for bestRAD libraries
To flip R1 and R2 when needed, takes unzipped fastq files as input
The script flip_trim_werrors.pl is downloaded from Galaxy
```
gunzip read1.fastq.gz

perl flip_trim_werrors.pl barcodes.txt read1.fastq read2.fastq outfile_read1.fq outfile_read2.fq true 2
```
format of barcode file: barcode<tab>sample
AAACGG  0606BZ
AACGTT  0607BZ
AACTGA  0643BZ

## Step 3 : demultiplex and remove adaptor sequences, for paired-end data
```
process_radtags -P -p data/RAD_150825/TSKR012  -o ./process_radtags-greenbul-RAD3-4000 -b greenbul-RAD3-barcodes -e sbfI -r -c -q -i gzfastq --adapter_1 GATCGGAAGAGCACACGTCTGAACTCCAGTC -- adapter_2 CACTCTTTCCCTACACGACGCTCTTCCGATCT
```
options: 
-P: paired end
-p: path to folder that store the raw reads (forward and reverse reads need to have matching names)
-o: path to output folder
-b: barcode file
-e: enzyme used
-i: indicate the raw data file is zipped
--adapter_1 and --adapter_2: the adapter sequences to be removed, these are the bestRAD adaptors in the example, need to change accordingly if you are using different protocol
-1 and -2: to specify forward and reverse input reads if not using -p

This step outputs 4 files for each sample:
two paired: sample.1.fq.gz and sample.2.fq.gz, 
two orphan reads: sample.rem.1.fq.gz and sample.rem.2.fq.gz
The output process_radtags.log file has all the information about demultiplex results.

we won’t use unpaired orphan reads for now, so I create a new folder to put them in there after this step is done.
```
cd process_radtags-greenbul-RAD3-4000
mkdir orphan
mv *rem* orphan
```

## Step 4 : remove pcr duplicates
```
cd process_radtags-greenbul-RAD3-4000
for sample in `ls *1.fq.gz | cut -f1 -d'.'`
do
    ~/bin/stacks1.32/bin/clone_filter -1 $sample.1.fq.gz -2 $sample.2.fq.gz -i gzfastq -o ../greenbul-RAD3-4000-dupfiltered
done
```
two output for each sample: sample.1.fq.fil.fq_1 and sample.2.fq.fil.fq_2
duplicate % in the stdout, for example on hoffman computing cluster, it’s “greenbul-rmdup-4000.e807168”
to extract useful info from this output, use grep
```
grep 'pairs of reads input' greenbul-rmdup-4000.e807168 | less –S
```

## Step 5: merge multiple datasets 
Optional when you have multiple plates or runs. use cat
put merged data, one per sample, first read only, to a new folder as the input folder for the following denovo assembly

## Step 6: choose parameter M for denovo assembly. 
1. use reasonable low m to avoid allele drop off. I use m=3
2. find out the sample that have median number of reads (for this example dataset I get sample MCZA_29492), 
3. ran ustacks using a range of M (1-8) and evaluate how many loci in the assembly has 1, 2, and 3+ alleles. I do array submissions on Hoffman
4. I plot it in R and chose M when the percentage of 2-allele loci reach plateu. For greenbul, sunbird and skinks, M=4 works well based on this step. 
```
#!/bin/bash
#$ -cwd
#$ -V
#$ -N parameter-optimization
#$ -l highp,h_data=3G,time=04:00:00
#$ -m bea
#$ -e ./logs/
#$ -o ./logs/
#$ -t 1-8:1

sample=merged/alldata/MCZA_29492.fq.gz

mkdir -p paramOpt/M$SGE_TASK_ID
/u/home/z/zhen/bin/stacks1.32/bin/ustacks -t gzfastq -f $sample -o paramOpt/M$SGE_TASK_ID -m 3 -M $SGE_TASK_ID -p 16 -H -d -r --bound_high 0.05 --model_type bounded
```
then you need to examine MCZA_29492.alleles.tsv.gz in each assembly and pull out the numbers. loop through all M
```
for i in 1 2 3 4 5 6 7 8
do
  cd M$i
  zcat MCZA_29492.alleles.tsv.gz | sed '1d' | cut -f3 | sort | uniq -c | sed -e 's/ *//' -e 's/ /\t/' > allele_ct
  cut -f1 allele_ct | sort | uniq -c | sed -e 's/ *//' -e 's/ /\t/' > allele_ct_sum
  sed -i "1 i\M$M\tct" allele_ct_sum 
  zcat MCZA_29492.tags.tsv.gz | tail -n 1 | cut -f3 >> ../total_loci 
  cd ..
done
```
special note: xxx.alleles.tsv don't have all the 1-allele loci, so you need to get this number from total_loci above

## Step 7: denovo assembly
```
mkdir denovo-skinks
cd merged/alldata/
inputL=`ls *.fq.gz | awk '{printf "-s "$1 " "}'`
echo "nohup ~/bin/stacks1.32/bin/denovo_map.pl -m 3 -M 4 -n 4 -S -b 5 -D 'skink' -T 8 -t --bound_high 0.05 -o ~/nobackup-klohmuel/skinks/denovo-skinks" $inputL " > ~/nobackup-klohmuel/skinks/denovo-skinks/nohup.out" | bash
```
## Step 8: correction mode - rxstacks, optional but recommended by stacks author.
rxstacks takes lots of memory, i.e. 100G, 9hrs for 200 bird samples. If memory allocation is not enough on cluster, sometimes it aborted without warning message for me. So you really need to check log file to make sure the run has finished, ie. the log file has a normal ending. 
```
mkdir denovo-sunbird-cor
~/bin/stacks1.32/bin/rxstacks -b 1 -P denovo-sunbird/ -o denovo-sunbird-cor/ --conf_lim 0.25 --prune_haplo --model_type bounded --bound_high 0.05 --lnl_lim -10.0 --lnl_dist -t 16 --verbose
```
rerun cstacks and sstacks after rxstacks
```
cd denovo-sunbird-cor
inputL=`ls *.tags.tsv.gz | cut -d '.' -f1 | awk '{printf "-s "$1 " "}'`
echo "nohup ~/bin/stacks1.32/bin/cstacks -n 4 -b 1 -p 36 -o ./" $inputL " >./nohup.out" | bash

gunzip batch_1.catalog*
for sample in `ls *.tags.tsv.gz | cut -d '.' -f1 `;
 do ~/bin/stacks1.32/bin/sstacks -b 1 -c ./batch_1 -s "$sample" -o ./ ;
done;
```
## Step 9: additional filters of RAD loci
1. use script get_consensus_tags.pl to retrieve consensus RAD loci that present in > 80% of all samples
```
perl ~/myscripts/get_consensus_tags.pl batch_5.catalog.tags.tsv 167
```
batch_5.catalog.tags.tsv is the output from denovo_map.pl or rxstacks step
167 is the total number of sample * 0.8, round up, here is 208*0.8, change this number according to your sample size

output files includes a list of consensus RAD loci in file RAD_consensus_ID

2. check SNP distribution patterns in these loci using script get_RAD_SNP.pl
```
perl ~/myscripts/get_RAD_SNP.pl RAD_consensus_ID batch_5.catalog.snps.tsv 
```
output gives the number of SNPs per loci, and the distribution of SNPs along the base positions of loci

3. remove loci that have too much polymorphic sites
I remove loci (94bp long) that have more than 40 SNPs
```
awk '$2<=40' RAD_consensus_ID.tags_SNPct | cut -f1 > RAD_consensus_ID_40
```

4. remove loci that are potentially paralogs (blat to each other)
```
/u/local/apps/blat/34/bin/blat RAD_consensus_sequence.fa RAD_consensus_sequence.fa RAD_consen_selfblat.psl
cut -f10 RAD_consen_selfblat.psl | sed '1,5d' | sort | uniq -d > RAD_consen_selfblat.Duplicates
comm -23 <(sort RAD_consensus_ID_40) <(sort RAD_consen_selfblat.Duplicates) > RAD_consensus_final
```

5. optional: if you have a reference genome of close relative, you can also map to it and remove tags that mapped to multiple positions of the genome

6. count how many consensus tags each sample has
I consider a sample bad if it doesn’t have >=80% of the consensus tags and remove them for final analysis.  
```
perl ~/myscripts/count_consensusTag_perSample.pl RAD_consensus_final batch_5.catalog.tags.tsv 208
```

## Step 10: run populations, export genotype information in VCF format
```
dir=/u/home/z/zhen/nobackup-klohmuel/skinks/denovo-skinks
~/bin/stacks1.32/bin/populations -P $dir -W $dir/RAD_consensus_final -r 0.8 -s -b 5 -t 36 --vcf 
```
Additionally but important! remove SNPs in the last 7 bp of RAD loci, where there is an enrichment of erroneous SNPs. 
```
perl ~/myscripts/remove_3priSNP_vcf.pl batch_1.vcf 
```
