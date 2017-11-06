#!perl -w
#by Ying Zhen
#perl get_RAD_SNP.pl RAD_ID_list batch_X.catalog.snps.tsv

########output 
#RAD_ID_list.SNP.tsv       SNP file for the RADlist  
#RAD_ID_list.tags_SNPct    RADtags and SNPcount for each RADtag 
#RAD_ID_list.bp_SNPct      base position along the RADtag where the SNP is observed & SNP number found in that positon across all RADcontigs

if (@ARGV <1){print "\nusage: get_RAD_SNP.pl RAD_ID_list snps.tsv\n\n";exit;}
$taglist = shift(@ARGV); chomp $taglist;
$snpfile = shift(@ARGV); chomp $snpfile;

open IN, $taglist or die "cannot find input RAD list";
open IN2, $snpfile or die "cannot find input SNP.tsv file";
open OUT, ">$taglist.SNP.tsv";

@id = ();
while ($id = <IN>){
    chomp $id;
    push (@id, $id);
}

%tag_SNP_ct=();
%bp_SNP_ct=();

while ($line = <IN2>){
    chomp $line;
    @element = split('\t', $line);
    if ($element[2] ~~ @id) {
	print OUT $line, "\n";
	
	$tag_SNP_ct{$element[2]}++;
	$bp_SNP_ct{$element[3]}++;
    }
}

open OUT2, ">$taglist.tags_SNPct";
open OUT3, ">$taglist.bp_SNPct";
print OUT2 "RADtagID\tSNPct\n";
print OUT3 "bp\tSNPct\n";

@keys = (keys %tag_SNP_ct);
foreach (@keys) {
    print OUT2 "$_\t$tag_SNP_ct{$_}\n";
}

@nosnp = grep{ not $_ ~~ @keys} @id;
#print "@nosnp";
foreach (@nosnp) {
    print OUT2 "$_\t0\n";
}  

foreach (keys %bp_SNP_ct) {
    print OUT3 "$_\t$bp_SNP_ct{$_}\n";
}


