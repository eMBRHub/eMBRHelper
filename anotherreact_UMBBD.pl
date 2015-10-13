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

my $UMBBD_react = "http://umbbd.msi.umn.edu/servlets/pageservlet?ptype=allreacs";
my $esearch_result = get($UMBBD_react);

my $reactID_fh = IO::String->new($esearch_result);
die "No String fh passed to the esearch results!\n" unless $reactID_fh;

open (SIFILE, ">anotherreaction records.sif") or die "Can't open file for write $!\n";
print SIFILE "Reaction"."\t"."Substrate"."\t". "Enzyme"."\t"."Product\n";


while (my $line = <$reactID_fh>){
my $reactionID; my $enz_name;my $brk = "PLUS";my @prd;my @sbrt; my $enzyme;
	if ($line =~ /.+reacID=(.+)\">(.+) -----&gt (.+) \(reacID\#/){
		$reactionID = $1;
		my ($enz_ID, $substrate, $product) = get_reaction_info($reactionID);
		if ($enz_ID){
				$enz_name = get_enzyme_name($enz_ID);
					if ($enz_name){
						$enzyme = $enz_name;
						}else{$enzyme = "Enzyme record not found";
					}
				}else {$enzyme = "No enzyme supplied";}
		
		#print "$reactionID\t$substrate\t$enz_name\t$product\n";
		if (($substrate !~ /PLUS/) && ($product =~ /PLUS/)){
			@prd = split(/PLUS/,$product);
			print SIFILE "$reactionID\t$substrate\t$enzyme\t$prd[0]\n";
			print SIFILE "$reactionID\t$substrate\t$enzyme\t$prd[1]\n";
			print "$reactionID\t$substrate\t$enzyme\t$prd[0]\n";
			print "$reactionID\t$substrate\t$enzyme\t$prd[1]\n";
			}
		if (($substrate =~ /PLUS/) && ($product !~ /PLUS/)){
			@sbrt = split(/PLUS/, $substrate);
			print SIFILE "$reactionID\t$sbrt[0]\t$enzyme\t$product\n";
			print SIFILE "$reactionID\t$sbrt[1]\t$enzyme\t$product\n";
			print "$reactionID\t$sbrt[0]\t$enzyme\t$product\n";
			print "$reactionID\t$sbrt[1]\t$enzyme\t$product\n";
			}
		if (($substrate !~ /PLUS/) && ($product !~ /PLUS/)){
			print SIFILE "$reactionID\t$substrate\t$enzyme\t$product\n";
			print "$reactionID\t$substrate\t$enzyme\t$product\n";
			}
	}

}

close (SIFILE);





###subroutines###
sub get_reaction_info{
	my($reactionID) = @_;
	my $url = "http://umbbd.msi.umn.edu/servlets/pageservlet?ptype=r&reacID=$reactionID";
		my $url_req = get($url);
		my $url_fh = IO::String->new($url_req);
		die "No String received from UMBBD reaction url!\n" unless $url_fh;

		my $enzymeID; my $subs; my $prod;my $subsr; my $prodt;	
		while(my $content = <$url_fh>){
			if ($content =~ /(.+)enzymeID=(e\d+)(\">)(.+)/){
			$enzymeID = $2;
			#print "Trying neww enzyme: $enzymeID\n";
			}
			if ($content =~ /<h1>From (.+) to (.+)<\/h1>/){
				$subs = $1;
				$prod = $2;
				$subs =~ s/<i>|<\/i>|<sup>|<\/sup>//ig;
				$prod =~ s/<i>|<\/i>|<sup>|<\/sup>//ig;
				$subsr = prep($subs);
				$prodt = prep($prod);
				#print "System works Substrate: $subsr and Product: $prodt\n";
			}
		}
		#print "First Subroutine: Enzyne ID: $enzymeID and Subtrate is $subsr and Product is $prodt\n";
		return ($enzymeID, $subsr, $prodt);
}


sub get_enzyme_name{
	my($enzymeID) = @_;
	#print "I've got to the second subroutine\n";
	#print "New enzyme Identity is $enzymeID\n";
	my $enz_url = "http://umbbd.msi.umn.edu/servlets/pageservlet?ptype=ep&enzymeID=$enzymeID";
	my $enzyme_req = get($enz_url);
	my $enzyme_fh = IO::String->new($enzyme_req); 
	die "No string received from Enzyme Request!\n" unless $enzyme_fh;
	
	my $enzyme_name;
	while (my $enz_entry = <$enzyme_fh>){
			if ($enz_entry =~ /Reactions catalyzed by <b>(.+)<\/b>/){
				$enzyme_name = $1;
				#print "Got to enxyme name: $enzyme_name\n";
				$enzyme_name =~ s/<i>|<\/i>//g;
				}			
			}
	return $enzyme_name;
}

sub prep{
	my($entity) = @_;
	chomp $entity;
	my $compd;my $entity1;my $entity2;
	if ($entity =~ /(.+) and (.+)/){
	$entity1 = $1;
	$entity2 = $2;
	chomp $entity1;
	chomp $entity2;
	$compd = "$entity1"."PLUS"."$entity2";	
	}else {$compd = $entity;}
	chomp $compd;
 return $compd;
}
