#!/usr/local/bin/perl -w
#====================================================================
#Software used during the pre- run stage of eMBRHelper,
#To populate the 'bsd_entries' database tables
#using data obtained from the Biodegradative Strain Database,
#also relates it with the compounds found to be degraded by the respective microorganisms (in the BSD).
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

#dbase handle & sql statements
my $dbh = DBI->connect($ds,$user,$passwd) || die "Cannot connect to database!!";

my $sth = $dbh->prepare("INSERT INTO bsd_entries (bsd_strain_id, bsd_strain_name) VALUES (?,?)");
my $sth2 = $dbh->prepare("INSERT INTO bsdcomp_degr (bsd_strain, comp_degr, bsd_comp_id) VALUES (?,?,?)");

my $bsd = "http://bsd.cme.msu.edu/jsp/ListController.jsp?object=Strain&attribute=name";
my $bsd_result = get($bsd); #use LWP::Simple

my $bsd_fh = IO::String->new($bsd_result);
die "No String fh passed to the esearch results!\n" unless $bsd_fh;

my @bsdIDs;
while (my $line = <$bsd_fh>){
	#print "$line\n";
	if ($line =~ /(.+)jsp\?object\=Strai(.+)id=(.+)\" onMouseOver(.+)/){
		my $bid = $3;
		my ($nam, @subs) = get_name_subr($bid);
		$nam =~ s/\s/ /g;
		
		#print "$bid\t$nam\n";
		$sth->execute($bid,$nam);
		foreach my $s (@subs){
			my @compdets = split (/\t/, $s );
			#print "$bid\t$compdets[1]\t$compdets[0]\n";
			$sth2->execute($bid,$compdets[1],$compdets[0]);
			}
		#push (@bsdIDs, $bid);
		}
	}
	

#==============================================
#subroutines#
#==============================================

sub get_name_subr{
	my ($entry) = @_;
	my $name; my $details; my @comprec; my $det2; my $det22 ; my $names; my $namm; my $namm1; my $namm2;
	my $bsdfile = "http://bsd.cme.msu.edu/jsp/InfoController.jsp?object=Strain&id=$entry";
	my $specentr = get($bsdfile);
	
	my $spec_fh = IO::String->new($specentr);
	die "No string fh passed for the bsd specific entry!\n" unless $spec_fh;
	
	while (my $detts = <$spec_fh>){
		$details .=$detts;
		
		if ($detts =~ /.+jsp\?object(.+)id\=(.+)\" (.+)status\=\'(.+)\'; return true\">/){
		my $chemid = $2;
		my $chem = $4;
		#print "First print:$chemid\t$chem\n";
		push(@comprec, "$chemid"."\t"."$chem");
		}
	}
			
	if ($details =~ /BSD Strain Data Page: Strain (.+?)<\/title>$/msg){
		$name = $1;
		#chomp $name;
		my @nama = split (/\n/, $name);
		chomp $nama[0]; 
		chomp $nama[1]; 
		chomp $nama[2];
		if ($nama[0] =~ /(\s+)(.+)/){$namm = $2}else {$namm = $nama[0];}
		if ($nama[1] =~ /(\s+)(.+)/){$namm1 = $2}else {$namm1 = $nama[1];}
		if ($nama[2] =~ /(\s+)(.+)/){$namm2 = $2}else {$namm2 = $nama[2];}
		$names = "$namm $namm1 $namm2";
		#$name =~ s/\n//g;
		}
	return ($names, @comprec);

}

$sth->finish;
$sth2->finish;
$dbh->disconnect;


