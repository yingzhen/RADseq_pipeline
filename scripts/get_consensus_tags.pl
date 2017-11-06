#!perl -w
#perl get_consensus_tags.pl batch_X.catalog.tags.tsv min_N 
##edited 2015-9-15 to check header line

if (@ARGV <2){print "\nusage: perl get_consensus_tags.pl batch_X.catalog.tags.tsv min_N\n\n";exit;}

$tagsfile = shift(@ARGV); chomp $tagsfile;
$min_N = shift(@ARGV); chomp $min_N;
open IN, $tagsfile or die "wrong batch_X.catalog.tags.tsv file";
open OUT, ">RAD_consensus_sequence.fa";
open OUT2, ">RAD_consensus_ID";
#debug distribution of missing data in each tag
#open OUT3, ">test";

$N=0;
while ($line = <IN>){
    if ($line =~ /^#/){}
    else{

	chomp $line;
	@tmp = split(/\t/, $line);
	$id = $tmp[2];
	$samples=$tmp[8];
	@tmp2 = split(',',$samples);
	#creat an array to count samples because some samples have multiple tags match to the same catelog
	my %counts = ();
	foreach $i (@tmp2){
	    (my $n)=split('_',$i);
	    $counts{$n}++;
	}

	$indiv = scalar(keys %counts);
	$tag_sequence= $tmp[9];
	
#	print OUT3 "$id\t$indiv\n";

	if ($indiv >= $min_N){
	    $N++;
	    print OUT ">$id","_$indiv\n";
	    print OUT "$tag_sequence\n";
	    print OUT2 "$id\n";
	}
    }
}
print "\n$N RAD tags are found in at least $min_N individuals\n\n";
