#!perl -w
#by Ying Zhen
#perl count_consensusTag_perSample.pl RAD_ID_list batch_X.catalog.tags.tsv sampleN

########output   
#extract from batch_X.catalog.tags.tsv the ones in the RAD_ID_list : RAD_ID_list.tags.tsv 
#count number of radtags in RAD_ID_list that's present in each sample: RAD_ID_list.sample_tagcount

if (@ARGV <1){print "\nusage: count_consensusTag_perSample.pl RAD_ID_list batch_X.catalog.tags.tsv sampleN\n\n";exit;}
$taglist = shift(@ARGV); chomp $taglist;
$tagfile = shift(@ARGV); chomp $tagfile;
$N = shift(@ARGV); chomp $N;

open LIST, $taglist or die "cannot find input RAD list";
open IN2, $tagfile or die "cannot find input batch_X.catalog.tags.tsv file";
open OUT, ">$taglist.tags.tsv";

@id = ();
while ($id = <LIST>){
    chomp $id;
    push (@id, $id);
}

%sample_tags=();
while ($line = <IN2>){
    chomp $line;
    @element = split('\t', $line);
    if ($element[2] ~~ @id) {
	print OUT $line, "\n";
	$samples=$element[8];
	@tmp = split(',',$samples);
	my @sampleL = ();
	foreach $i (@tmp){
	    (my $n)=split('_',$i);
	    push @sampleL, $n;
	}
	
	foreach $m (1..$N){
	    if ($m ~~ @sampleL){$sample_tags{$m}++;}
	}
    }
}

open OUT2, ">$taglist.sample_tagcount";
print OUT2 "sample\tConsenTagN\n";

@keys = (keys %sample_tags);

foreach (@keys) {
    print OUT2 "$_\t$sample_tags{$_}\n";
}




