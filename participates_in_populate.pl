#!/usr/local/bin/perl -w
#====================================================================
#Software used during the pre- run stage of eMBRHelper,
#To populate the 'participates_in' database table 
#contains reactions and which compounds participate in them, as either substrates or products,
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
my $ds = "DBI:mysql:eMBR_helper:localhost";
my $user = "root";
my $passwd = "S952pa74lkp";

#dbase handle
my $dbh = DBI->connect($ds,$user,$passwd) || die "Cannot connect to database!!";

#read all of the reactions data
#for each reaction id obtain UMBBD reaction ID
#read off UMBBD reactions txt
#obtain substrate, product 
#populate participates in with reactio id, compound name and role

my $sth = $dbh->prepare("SELECT reaction_id, UMBBDr_id, source FROM reactions");
my $sth2 = $dbh->prepare("INSERT INTO participates_in (reaction_iden, compound_name, role, source) VALUES (?,?,?,?)");
my $sth3 = $dbh->prepare("SELECT reaction_id, Keggr_id, source FROM reactions");
#read all of reactions data
$sth->execute();


#process all outcomes of query
while (my @outs = $sth->fetchrow_array()){
	next if $outs[1] eq "No equiv. UMBBDr";
	my @details = get_dets($outs[1]);
	foreach my $line (@details){
	my @li = split(/\t/, $line);
	my $role1 = "substrate";
	my $role2 = "product";
	chomp $li[0]; chomp $li[1];
	print "========POPULATING participation database: RNo:$outs[1]: DONE!!\n";
	$sth2->execute($outs[0],$li[0],$role1,$outs[2]);
	$sth2->execute($outs[0],$li[1],$role2,$outs[2]);
	}
}

#same for kegg records
$sth3->execute();
#process details as with UMBBD
while (my @outk = $sth3->fetchrow_array()){
	next if $outk[1] eq "No equiv. KEGGr";
	next if $outk[2] eq "UMBBD/KEGG";
	my @detailk = get_detk($outk[1]);
	foreach my $linek (@detailk){
	my @li = split(/\t/, $linek);
	my $role1 = "substrate";
	my $role2 = "product";
	chomp $li[0]; chomp $li[1];
	print "========POPULATING participation database: RNo:$outk[1]: DONE!!\n";
	$sth2->execute($outk[0],$li[0],$role1,$outk[2]);
	$sth2->execute($outk[0],$li[1],$role2,$outk[2]);
	}
}

$sth->finish;
$sth2->finish;
$dbh->disconnect;
close (UMDET);
close (KGDET);


########Subroutines########

sub get_dets{
	my ($r) = @_;
	my $subs; my $prods; my @retval;
	unless(open(UMDET, "UMBBD reactions.txt")){print "Could not open UMBBD reactions file!\n";}
	while (my $dets = <UMDET>){
		my @det = split(/\t/, $dets);
		if ($r eq $det[0]) {
			$subs = $det[1]; 
			$prods = $det[3];
			push(@retval, ("$subs"."\t"."$prods"));}
		} 
	return @retval;
}

sub get_detk{
	my ($k) = @_;
	my $subk; my $prodk; my @retvalk;my $kegd;
	unless(open(KGDET, "kegg_node_edge_records.csv")){print "Could not open KEGG reactions file!\n";}
	while (my $detk = <KGDET>){
		my @detk = split(/\t/, $detk);
		$kegd = $detk[0];
		$kegd =~ s/rn://;
		if ($k eq $kegd) {
			$subk = $detk[1]; 
			$prodk = $detk[3];
			push(@retvalk, ("$subk"."\t"."$prodk"));}
		} 
	return @retvalk;
}
