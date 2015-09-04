#!/usr/local/bin/perl -w
#====================================================================
#Software used during the pre- run stage of eMBRHelper,
#To populate the 'enzymes_in' database table
#using data on microorganisms where specified enzymes are found, from data contained in BRENDA.
#Used get( ) function of LWP::Simple
#Chijoke Elekwachi, MyCIB, Univ of Nottingham. UK, 2010
#====================================================================
use strict;
use warnings;
use LWP::Simple;
use IO::String;
use DBI;
#use lib for DBD::mySQL
use lib '/usr/lib/perl5/site_perl/5.8.8/i386-linux-thread-multi/DBD/mysql.pm';

#connect to the database
my $ds = "DBI:mysql:xxxxx:localhost";#replace xxxx with database name
my $user = "root";
my $passwd = "xxxxxx"; #replace xxxx with appropriate password

#dbase handle
my $dbh = DBI->connect($ds,$user,$passwd) || die "Cannot connect to database!!";

#sql statements and queries
my $sth = $dbh->prepare("SELECT enzyme_id, EC_No FROM enzymes");
$sth->execute;
my $sth2 = $dbh->prepare("SELECT microbe_id FROM microorganisms WHERE strain_name LIKE ?");
my $sth3 = $dbh->prepare("INSERT INTO enzyme_in (enzymeID, microbeID, enzymeName, microbeName, no_of_bases, fasta_heading, prot_seq, courtesy) VALUES (?,?,?,?,?,?,?,?)");
my $sth4 = $dbh->prepare("INSERT INTO microorganisms (strain_name, BSD_entry_id, source) VALUES (?,?,?)");
my $sth5 = $dbh->prepare("SELECT bsd_strain_id FROM bsd_entries WHERE bsd_strain_name LIKE ?");


my $e_name; my $courtesy = "BRENDA";
while (my @ECs = $sth->fetchrow_array()){
	my $eid = $ECs[0];
	my $ec = $ECs[1]; 
	chomp $ec; 
	#print "EC No:$ec\n";
	if ($ec eq "NULL"){next;}
	if ($ec =~ /\d+\.-\.-\.-/){next;}
	if ($ec =~ /\d+\.\d+\.-\.-/){next;}
	if ($ec =~ /\d+\.\d+\.\d+\.-/){next;} #only use ECs for completely numbered enzymes
	else{
	my $url = "http://www.brenda-enzymes.info/sequences/seq_tsv_EC_download.php4?ec=$ec";
	my $incoming = get($url);

	my $url_fh = IO::String->new($incoming);
	die "Unable to open the filehandle!\n" unless $url_fh;

	my @finals; my $l; my @entry; my $num; my $org;
	while (my $line = <$url_fh>){
	
	if($line =~ /\#This file is/){next;}
	if($line =~ /Access/){next;}
	my ($ascesion, $e_name, $sequence, $num, $org) = process_entry($line);
	chomp $sequence;
	print "$ascesion\n$sequence\nNo of bases:\t$num\nOrganism:\t$org\n\n";
	
	#obtain microbes info
	my $microbe_id = get_micr_id($org);
	print "Microbe ID: $microbe_id\n\n";
	if ($microbe_id ne "null"){
			$sth3->execute($eid,$microbe_id,$e_name,$org,$num,$ascesion,$sequence,$courtesy); #populate enz_in
			print "Populating enzyme_in microorganism NOT NULL\n\n";
			}else{	my $b = get_bsd($org);#get BSD code if any
				&populate_microbe($org,$b);
				print "Just populated microorganisms with $org\n\n";
				my $new_micID = get_micr_id($org);
				print "New microbe Id: $new_micID\n";
				if ($new_micID ne "null"){
				$sth3->execute($eid,$new_micID,$e_name,$org,$num,$ascesion,$sequence,$courtesy);
				print "DONE!!\n";
				}else {print "Can't return NULL after inserting new microbe entry\n\n";}
			}
		}
	}	
}


######subroutiines#######

sub process_entry{
		my ($content) = @_; 
		my $fastaseq; my $fa1; my $fa2;my $fa3;
		
		my @block = split (/\t/, $content);
		my $fhd = ">";
		my $asc = $block[0];
		my $enzname = $block[1];
		my $EC = $block[2];
		my $orgs = $block[3];
		my $src = $block[4];
		my $numbr = $block[5];
		my $seqq = $block[6];
		$fa1 = "$fhd$asc|$enzname|$EC|$orgs|$src";
		
	return ($fa1, $enzname, $seqq, $numbr, $orgs);
}



sub get_micr_id{
	my ($mic) = @_;
	my $m;
	$sth2->execute($mic);

	my @result = $sth2->fetchrow_array();
	my $m_id = $result[0];
	if($m_id){$m = $m_id;} else{$m = "null";}
	return $m;

}


sub get_bsd{
	my ($name)= @_;
	my $b;
	$sth5->execute($name);

	my @resbsd = $sth5->fetchrow_array();
	my $bs = $resbsd[0];
	if($bs){$b = $bs;} else{$b = "null";}
	return $b;
}



sub populate_microbe{
	my ($micr, $bs) = @_;
	my $src = "BRENDA";
	$sth4->execute($micr,$bs,$src);
	print "populating microorganism now with info: $micr DONE!!\n";

}
