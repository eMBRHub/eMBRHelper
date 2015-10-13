#!/usr/local/bin/perl -w
use strict;
use warnings;
use LWP::Simple;
use IO::String;

#BEGIN
#{
#open (STDERR,">>$0-err.txt");
#print STDERR "\n",scalar localtime,"\n";
#}

my $KEGG_react1 = "http://www.genome.jp/kegg/pathway.html";
my $kegg_results = get($KEGG_react1);

my $keggID_fh = IO::String->new($kegg_results);
die "No String fh passed to the keggsearch results!\n" unless $keggID_fh;

my $rel_section;my $section;my @map_numbers;my $kegg_num; my $keggpathname; my $keggrn;my @rnumbs;
my $keggrnurl; my $keggrn_fh; my $keggrncontent; my $rxnurl; my $rxncontent; my $rxn_fh;
my $kenzyme_name; my $keggenz_name; my $ksubstrate, my $kproduct; my $line;my $keggenzurl; my $enz_line;my $enzyme_num;

while ($line = <$keggID_fh>){
	$section .= $line;
	}
	if ($section =~ /.*Xenobiotics Biodegradation and Metabolism<\/b>(.+?)<\/table>.*/msg){
		$rel_section = $1;
		}
	my $mapnos_fh = IO::String->new($rel_section);
	
#obtain kegg map numbers
	
while (my $map_num = <$mapnos_fh>){
	
	if ($map_num =~ /.+\/.ap\/(.+).html\">(.+)<\/a>/){
		$kegg_num = $1;
		$keggpathname= $2;
		push(@map_numbers, $kegg_num);	
		#print "$kegg_num\n";		
		}	 
	}

#obtain reaction IDs
foreach my $item (@map_numbers){
	$keggrnurl = "http://www.genome.jp/dbget-bin/get_linkdb?-t+reaction+path:$item";
	#print " Got to item no : $item\n";
	$keggrncontent	= get($keggrnurl);
	$keggrn_fh = IO::String->new($keggrncontent);
	die "No String fh passed for Kegg reaction url\n" unless $keggrn_fh;
	
	while (my $line2 = <$keggrn_fh>){
		if ($line2 =~ /.+www_bget\?(.+)\">.+<\/a>/){
			$keggrn = $1;	
			#print "$keggrn\n";	
			push(@rnumbs, $keggrn);
			}
		}
		
	}

#obtain & print reaction info to sif file
#open (KEGGSIFILE, ">>kegg_node_edge_records.sif") or die "Can't open file for write $!\n";
open (KEGGSIFILE, ">>second_kegg_node_edge_records.sif") or die "Can't open file for write $!\n";
print KEGGSIFILE "Reaction Number"."\t"."Substrate"."\t". "Enzyme Number"."\t"."Enzyme"."\t"."Product\n";

foreach my $number (@rnumbs){
		#print "Got to this point of nuymbers :::$number\n";
		($enzyme_num, $ksubstrate, $kproduct) = get_kegg_rxn_info($number);

		if($enzyme_num){$kenzyme_name = get_kegg_enzyme_name($enzyme_num);}
			else {$kenzyme_name = "No Kegg enzyme supplied";}

		print "$number\t$ksubstrate\t$enzyme_num\t$kenzyme_name\t$kproduct\n";
		print KEGGSIFILE "$number\t$ksubstrate\t$enzyme_num\t$kenzyme_name\t$kproduct\n";
		}


close (KEGGSIFILE);



###subroutines###
sub get_kegg_rxn_info{
	my ($reactnum) = @_;
	$rxnurl = "http://www.genome.jp/dbget-bin/www_bget?$reactnum";
	$rxncontent = get($rxnurl);
	$rxn_fh = IO::String->new($rxncontent);
	die "No String fh passed for kegg enzyme reaction content!\n" unless $rxn_fh;

	my $rel_line; my $reaction_eq; my $enzyme_no;my $ksub; my $kprod;
	while (my $line3 = <$rxn_fh>){
		$rel_line .= $line3;
		} 
		if ($rel_line =~ /^<tr>(.+)Definition<\/nobr><\/th>\n(.*?)solid\">(.*?)<\/td><\/tr>$/msg){
			$reaction_eq = $3;
			}
		if ($rel_line =~ /^<tr>(.+)Enzyme<\/nobr><\/th>\n(.*?)www_bget\?ec:(.*?)\">.+$/msg){
			$enzyme_no = $3;
			}
			
	if ($reaction_eq =~ /(.+)&lt;=>(.+)/){$ksub = $1; $kprod = $2;}	
	$ksub =~ s/<br>//g; $kprod =~ s/<br>//g;
	chomp $ksub; chomp $kprod;
	
	$ksubstrate = k_prep($ksub);
	$kproduct = k_prep($kprod);
	
	return ($enzyme_no, $ksubstrate, $kproduct);
}


sub get_kegg_enzyme_name{
	my ($kegenzno) = @_;
	my $keggenzurl = "http://www.genome.jp/dbget-bin/www_bget?ec:$kegenzno";
	my $kenz_req = get($keggenzurl);
	my $kenz_fh = IO::String->new($kenz_req);
		die "No String received from UMBBD reaction url!\n" unless $kenz_fh;

	while(my $enzcontent = <$kenz_fh>){
		$enz_line .= $enzcontent;
		}
 		if ($enz_line =~ /^<tr>(.+)Name<\/nobr><\/th>\n(.*?)solid\">(.+?)<\/td><\/tr>$/msg){
			my $keggenz_block = $3;
			$keggenz_name = clean_keg_enz($keggenz_block);
		}
		elsif($enz_line =~ /^<tr>(.+)Class<\/nobr><\/th>\n(.*?)solid\">(.+?)<a href\=\".+<\/tr>$/msg){
			my $keggclass_block = $3;
			$keggenz_name = clean_keg_enz($keggclass_block);
		}  
	return $keggenz_name;
	}


sub k_prep{
	my ($kcomp) = @_;
		my $element; my @possibles; my @final_possibles;

	if ($kcomp =~ /\+/){@possibles = split(/\+/, $kcomp);} else {$kcomp = $element;}

	if (@possibles){
	foreach my $content (@possibles){
	chomp $content;
	next if ($content =~ /^\s*$/); #skip blanks
	if ($content =~ /^\s.*/){$content =~ s/\s//;}
	next if ($content =~ /NAD|Sulfate|Diphosphate|NH3|H2O2|H2O|Oxygen|\bH\b|Formate|Acetate|FAD/);
	next if ($content =~ /ATP|AMP|CoA|CO2|Ferredoxin/);
	push(@final_possibles, $content);
	}
	
#organise entities
	if (scalar@final_possibles == 1){
		$element = $final_possibles[0];
		}
	if (scalar@final_possibles == 2){
		$element = $final_possibles[0]."&&".$final_possibles[1];
		}
	if (scalar@final_possibles == 3){
		$element = $final_possibles[0]."&&".$final_possibles[1]."&&".$final_possibles[2];
		}
	else{
		for my $a (0 .. $#final_possibles)
			{
			$element = $final_possibles[$a], "&&"; 
			}
		}

	}
	return $element;
}


sub clean_keg_enz{
	my ($block) = @_;
	$block =~ s/<br>//g;
	my @block_content = split(/;/, $block);
	my $clean = $block_content[0];
	return $clean;
}
