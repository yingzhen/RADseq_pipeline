# RADseq_pipeline
I describe here the pipeline I used to process RADseq data from non-model organisms without a reference genome. The pipeline starts with fastq files returned from sequencing center and finishes with a list of loci that pass various filters and variants in VCF format.

## install stacks 1.32
download stacks from http://catchenlab.life.illinois.edu/stacks/, where also hosts good tutorial and information of the stacks pipeline

```
tar xzvf stacks-1.32.tar.gz
cd stacks-1.32
./configure --prefix=/u/home/z/zhen/bin/stacks1.32
make
make install
```

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



