#!/usr/local/bin/perl -w
#====================================================================
#Software used during the pre- run stage of eMBRHelper,
#To populate the 'UMBBD_GO' and the 'KEGG_GO' database tables
#using data obtained from Gene Ontology.
#Parses informtaion from the relevant GO vocabulary mapping files.
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
#after then sth = dbh->prepare("select/insert....."); then sth->execute
my $sth = $dbh->prepare("INSERT INTO umbbd_go(umbbdr_ident , GO_desc , GO_num) VALUES(?,?,?)");
my $sth2 = $dbh->prepare("INSERT INTO kegg_go(keggr_ident , GO_descr , GO_number) VALUES(?,?,?)");


my $id; my $term; my $number;my $krid; my $kterm, my $knumber;
	
unless(open(UMBBDGO, "um-bbd_reactionid2go.txt")) {print "Could not open umbbdr2go file!\n";} #mapping file earlier downloaded and saved within active directory

	while (my $goline = <UMBBDGO>){
		next if $goline =~ /!/;
		if ($goline =~ /UM-BBD_reactionID:(.+) > (.+) ; (.+)/){$id = $1; $term = $2; $number = $3;
		$sth->execute($id,$term,$number);
		}
	}
	

unless(open(KEGGGO, "keggr2go.txt")) {print "Could not open keggr2go file!\n";} #mapping file earlier downloaded and saved within active directory

while (my $kgline = <KEGGGO>){
		next if $kgline =~ /!/;
		if ($kgline =~ /KEGG:(.+) > (.+) ; (.+)/){$krid = $1; $kterm = $2; $knumber = $3;
		$sth2->execute($krid,$kterm,$knumber);
		}
	}


close (UMBBDGO);
close (KEGGGO);

$sth->finish;
$sth2->finish;
$dbh->disconnect;
