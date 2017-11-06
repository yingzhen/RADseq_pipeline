#!perl -w
#by Ying Zhen
#perl check_vcf_position.pl vcffile
use strict;
use warnings;

my $infile = shift(@ARGV); chomp $infile;
open IN, $infile or die "cannot open vcf file\n\n";
open OUT, ">$infile.87bp";


while (my $line = <IN>)
{
	chomp $line;
	if ($line =~ m/^#/)
	{
		print OUT $line, "\n";
	}
	else 
	{
		my @line = split('\t', $line);
		my $pos = ($line[1]-1) % 94; #94 is your read length, modify if the reads are trimmed
		if (($pos > 0) && ($pos <= 87)) #removes the last 7bp
		{   #0 is position 80	
		print OUT $line, "\n";
		}
	}
}

close OUT;
#close OUT2;
