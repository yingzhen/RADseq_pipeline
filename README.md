# RADseq_pipeline
I describe here the pipeline I used to process RADseq data from non-model organisms without a reference genome. The pipeline starts with fastq files returned from sequencing center and finishes with a list of loci that pass various filters and variants in VCF format.

# install stacks 1.32
download stacks from http://catchenlab.life.illinois.edu/stacks/, where also hosts good tutorial and information of the stacks pipeline

```
tar xzvf stacks-1.32.tar.gz
cd stacks-1.32
./configure --prefix=/u/home/z/zhen/bin/stacks1.32
make
make install
```

# Step 1: check data quality using fastqc
```
zcat TSKR012_S13_L003_R1_001.fastq.gz | fastqc stdin
```

# Optional Step 2 for bestRAD libraries
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

# Step 3 : demultiplex and remove adaptor sequences, for paired-end data
```
process_radtags -P -p data/RAD_150825/TSKR012  -o ./process_radtags-greenbul-RAD3-4000 -b greenbul-RAD3-barcodes -e sbfI -r -c -q -i gzfastq --adapter_1 GATCGGAAGAGCACACGTCTGAACTCCAGTC -- adapter_2 CACTCTTTCCCTACACGACGCTCTTCCGATCT
```

