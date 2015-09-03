#!/usr/local/bin/perl -w
#====================================================================
#Software used during the pre- run stage of eMBRHelper,
#To populate the 'rxn_pathw' database table
#This relates reactions with metabolic/degradation pathways in which they are found.
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

my $sth = $dbh->prepare("SELECT deg_pathw_id, umbbdpath_id FROM deg_pathways");
$sth->execute;
my $sth6 = $dbh->prepare("SELECT reaction_id FROM reactions WHERE UMBBDr_id = ?");
my $sth7 = $dbh->prepare("INSERT INTO rxn_pathw (reactionID, degpathID) VALUES (?,?)");


my $p_id; 
while (my @ptws = $sth->fetchrow_array()){
	$p_id = $ptws[0];
	my $umb_path = $ptws[1];
	
	
	#process umbbd page;
	my $degpath = "http://umbbd.msi.umn.edu/servlets/pageservlet?ptype=p&pathway_abbr=$umb_path";
	my $obtpath = get($degpath);

	my $umpath_fh = IO::String->new($obtpath);
	die "Unable to open the filehandle!\n" unless $umpath_fh;
	
	while (my $pline = <$umpath_fh>){
		if($pline =~ /<li><a href(.+)reacID=(.+)\">(.+)/){
			my $r_id = $2;
			my $rxn_id = get_reactionID($r_id);
			#print "$rxn_id\t$p_id\n";
			$sth7->execute($rxn_id,$p_id);
		}

	}

}

##########subroutines############
sub get_reactionID{
	my ($r) = @_;
	my $rID; my $id;
	$sth6->execute($r);

	my @reac = $sth6->fetchrow_array();
	$rID = $reac[0];
	if($rID){$id = $rID;} else{print "Reaction identity cannot return NULL. Check get_reactionID script\n";}
	return $id;
}
