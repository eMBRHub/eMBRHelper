#!/usr/local/bin/perl -w
#====================================================================
#Software used during the pre- run stage of eMBRHelper,
#To populate the 'microorganism' and 'deg_pathways' database tables
#using data obtained from UMBBD microorganisms listing.
#also relates the microorganism with the degradation pathways which they initiate/catalyse.
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
my $sth = $dbh->prepare("INSERT INTO microorganisms(strain_name, BSD_entry_id, source) VALUES(?,?,?)");
my $sth2 = $dbh->prepare("SELECT bsd_strain_id FROM bsd_entries WHERE bsd_strain_name LIKE ?");
my $sth3 = $dbh->prepare("INSERT INTO deg_pathways(pathw_name, initiating_micr, umbbdpath_id, pathw_descr) VALUES(?,?,?,?)");


#start from list of all microorganisms UMBBD
my $um_micro = "http://umbbd.msi.umn.edu/servlets/pageservlet?ptype=allmicros";
#my $um_micro1 ="http://umbbd.ethz.ch/servlets/pageservlet?ptype=allmicros"; # another mirror in case US site is down
my $micro_results = get($um_micro);

my $micr_fh = IO::String->new($micro_results);
die "No String fh passed to the keggsearch results!\n" unless $micr_fh;

my $contents;my $entries;my @listing; my @list;my $MicrURL; my $MicrName;
my $PathURL; my $PathName; my $src1 = "UMBBD";
while (my $mic = <$micr_fh>){
	$contents .=$mic;
	}

if ($contents =~ /As of (.+)strains.<P(.+?)<\/table>.*/msg){
	$entries = $2;
	}
	my $content_fh = IO::String->new($entries);

while (my $ents = <$content_fh>){
	@listing = split(/<\/tr>/, $ents);
	}

foreach my $micpath (@listing){
	@list = split(/<\/td>/, $micpath);
	my $micro = $list[0];
	my $path = $list[1];
	#print "$micro\t$path\n";

	if ($micro =~ m/\"(.+)\"><i>(.+)$/) {
		$MicrURL = $1;
		$MicrName = $2;
		$MicrName =~ s/<\/i>//;
		$MicrName =~ s/<\/a>//;
		#$MicrName =~ s/\s//g;
		}elsif ($micro =~ m/(.+)<i>(.+)$/){
		$MicrURL = "";
		$MicrName =$2;
		$MicrName =~ s/<\/i>//;
		$MicrName =~ s/<\/a>//;
		}
	
	if ($path =~ m/\"(.+)\">(.+)<\/a>$/){
	$PathURL = $1;
	$PathName= $2;
	}
	#print "$MicrName\t$PathName\n";
	my $bsd = get_bsd($MicrName);
	my ($pathid, $pathdes) = get_pathinfo($PathName);

	$sth->execute($MicrName,$bsd,$src1); 
	print "Populating Microorganism table:  $MicrName: DONE!\n";
	$sth3->execute($PathName,$MicrName,$pathid,$pathdes); 
	print "Populating Pathway table:  $PathName: DONE!\n";
}

####subroutines########

sub get_pathinfo {
		my ($pname) = @_;
		my $pline; my $p_name; my $p_id;my $p_desc;
		my $pathlink = "http://umbbd.msi.umn.edu/servlets/pageservlet?ptype=allpathways";
		my $pathr = get($pathlink);

		my $pathr_fh = IO::String->new($pathr);
		die "No String fh passed to the keggsearch results!\n" unless $pathr_fh;
		
		while (my $pline = <$pathr_fh>){
			if ($pline =~ /<li><a href(.+)html\">(.+) \((.+)\)<\/a>/){
				$p_name = $2;
				#my $p_id = $3;
				if($pname eq $p_name){$p_id = $3;}
			}
		#print "$contents\n";
		}
		$p_desc = get_desc($p_id);

		return ($p_id, $p_desc);

}


sub get_desc{
	my ($des) = @_;
	my $reldes; my $dline; my $ds;
	my $desclink = "http://umbbd.msi.umn.edu/$des/$des\_map.html";
	#my $desclink2 = "http://umbbd.ethz.ch/$des/$des\_map.html"; #mirror in case US site down
	my $descr = get($desclink);

	my $descr_fh = IO::String->new($descr);
	die "No String fh passed to the keggsearch results!\n" unless $descr_fh;

	while ($dline = <$descr_fh>){$ds .=$dline;}

if ($ds =~ /This pathway(.+?)(<p>|<P>|<P align=left>)(.+?)(The following is a .+|Organisms.+|This is a text-.+|This map is also.+)/msg){
		$reldes = $3;
		$reldes =~ s/<p>|<P>|<P align=left>/\n/g; #remove all the possible confusing html tags
		$reldes =~ s/<\/p>|<\/P>/\n/g;
		}
	return $reldes;
}



sub get_bsd{
	my ($name)= @_;
	my $b;
	$sth2->execute($name);

	my @result = $sth2->fetchrow_array();
	my $bs = $result[0];
	if($bs){$b = $bs;} else{$b = "null";}
	return $b;

}
