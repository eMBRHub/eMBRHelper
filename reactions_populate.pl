#!/usr/local/bin/perl -w
#====================================================================
#Software used during the pre- run stage of eMBRHelper,
#To populate the 'reactions' database table
#In the process also populates the 'enzymes' and 'enzymes_syns' tables using 
#information found not to have been captured in earlier population steps.
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
#prepare sql statements and queries
my $sth = $dbh->prepare("INSERT INTO reactions(UMBBDr_id, Keggr_id, enzyme_ident, source) VALUES(?,?,?,?)");
my $sth2 = $dbh->prepare("SELECT enzyme_id FROM enzymes WHERE enzyme_name LIKE ?");
my $sth3 = $dbh->prepare("INSERT INTO enzymes(enzyme_name, UMBBDe_id, Kegge_id, EC_No, BRENDAe_id, GO_term, GO_no,source) VALUES(?,?,?,?,?,?,?,?)");
my $sth4 = $dbh->prepare("INSERT INTO enzymes_syns(enzz_syn, root_enzy_name, source) VALUES (?,?,?)");


my @seenkegg;
#open UMBBD reactions file
unless(open(UMBBDR, "UMBBD reactions.txt")) {print "Could not open umbbdreactions file!\n";}

#obtain info for UMBBD
while (my $react_line = <UMBBDR>){
	my $source;
	next if $react_line =~ /Reaction/;
	my@rinfo = split(/\t/, $react_line);
	my $reactno = $rinfo[0]; #reaction number
	my $reacts = $rinfo[1]; #substrate
	my $reacte = $rinfo[2]; #enzyme
	my $reactp = $rinfo[3]; #product
	my $kreactno = get_KEGG_reactno($reactno,$reacts,$reacte,$reactp);
	my $enz = get_enzymeID($reacte);
	if ($kreactno =~ /R\d+/){$source = "UMBBD/KEGG";}
			elsif($kreactno eq "No equiv. KEGGr"){$source = "UMBBD";}
			else{$source = "UMBBD";}

	#write to db
	$sth->execute($reactno,$kreactno,$enz,$source);
	print "=============>Populating REACTION database: UMBBD records: DONE. Reaction No:\t$reactno\n";
}

#do same for kegg reactions
#open KEGG reactions file
unless(open(KEGGR, "kegg_node_edge_recordsconcluded.csv")){print "Could not open kegg reactions file!\n";}
while (my $keggr_line = <KEGGR>){
	next if $keggr_line =~ /Reaction Number/;
	my @krinfo = split(/\t/, $keggr_line);
	my $kreactn = $krinfo[0];
	$kreactn =~ s/rn://;
	my $kreactsub = $krinfo[1];
	my $kreactenz = $krinfo[2];
	my $kreactpr = $krinfo[3];
	my $enz_id = get_enzymeID($kreactenz);
	my $r_umb = "No equiv. UMBBDr";
	my $ksource = "KEGG";
	if($enz_id eq "null"){ 
		&repopulate_enz($kreactn);   #to make up for reactions that may not be in enzymes table
		} else { my $umbchk = check_UMB($kreactsub,$kreactenz,$kreactpr);
			if($umbchk eq "NO"){
			$sth->execute($r_umb,$kreactn,$enz_id,$ksource);#write to db
			print "=============>Populating REACTION database: KEGG records: DONE. Reaction No:\t$kreactn\n";
			}
		} 
	#note that if the record already exists from UMBBD then the database will not populate it.		
	}

close (KEGGR);
close (UMBBDR);

$sth->finish;
$sth2->finish;
$sth3->finish;
$sth4->finish;
$dbh->disconnect;



########Subroutines######################

sub get_KEGG_reactno{
	my ($rxno, $rxns, $rxne, $rxnp) = @_;
	my @kgr;my $keggrno;my $ans;
	unless(open(KEGGR, "kegg_node_edge_records.csv")){print "Could not open kegg reactions file!\n";}
	while (my $kegg_line = <KEGGR>){
		@kgr = split(/\t/, $kegg_line);
		if (($rxns =~ /^\Q$kgr[1]\E$/i) && ($rxnp =~ /^\Q$kgr[3]\E$/i)) {$keggrno = $kgr[0]; $keggrno =~ s/rn://;
		}
	}

	if($keggrno){$ans = $keggrno;}else{$ans = "No equiv. KEGGr";};
	return $ans;

}



sub get_enzymeID{
	my ($umrx_name) = @_;
	my $n;
	$sth2->execute($umrx_name);

	my @result = $sth2->fetchrow_array();
	my $enumb = $result[0];
	if($enumb){$n = $enumb;} else{$n = "null";}
	return $n;
}



sub repopulate_enz{
	my ($oth_reactn) = @_;
	
	my $keggid = "http://www.genome.jp/dbget-bin/www_bget?rn:$oth_reactn";
	my $enzyme_result = get($keggid);

	my $enzymeRD_fh = IO::String->new($enzyme_result);
	die "No String fh passed to the esearch results!\n" unless $enzymeRD_fh;
	
	my $enzll;
	while (my $enzrurl = <$enzymeRD_fh>){
		$enzll .= $enzrurl;
	}
	
	my $kegns_fh;my @kcomps;my $enz_idd;my $keggen_name, my $bbrenda_id; my $keggenzyme;
	if ($enzll =~ /<tr><th(.*)<nobr>Enzyme<\/nobr><\/th(.*?)dbget-bin\/www_bget\?ec:(.+?)\">(.+?)<\/td><\/tr>$/msg){
			$enz_idd = $3;
			$enz_idd =~ s/<br>|<\/div>|;//g;
		}
		
	
	#get the enzyme records:
	($keggen_name, $bbrenda_id) = get_KEGG_d($enz_idd);
	
	if($keggen_name){
		$keggenzyme = $keggen_name;		
		}else{
			$keggenzyme = get_KEGG_c($enz_idd);
		}

	#print "Kegg enzyme\t$keggenzyme\n";
	my $k_number = "ec:"."$enz_idd";
	my $umb_enz_no = "NO UMBBD enzyme record"; #bc enzyme name is unique in db. this will only be inserted if not.
	#get keggno GO and Go number
	my ($kontolt, $kontoln) = getECGO($enz_idd);
	
	my $source3 = "KEGG";
	#print "Kegg Records: $keggenzyme\t$umb_enz_no\t$k_number\t$enz_idd\t$bbrenda_id\t$kontolt\t$kontoln\n";
	$sth3->execute($keggenzyme,$umb_enz_no,$k_number,$enz_idd,$bbrenda_id,$kontolt,$kontoln,$source3);
	print "=============>Populating enzyme database: KEGG records: DONE. Enzyme:\t$keggenzyme\n";
}



sub get_KEGG_d{
	my ($eid) = @_;
	my $urlk = "http://www.genome.jp/dbget-bin/www_bget?ec:$eid";
	my $urlfile = get($urlk);
	my $url_fh = IO::String->new($urlfile);
	die "NO String filehandle supplied for kegg enzyme fh!\n" unless $url_fh;
	
	my $urff;my $enzname;my $brenda;my $br;my $source3 = "KEGG";
	while (my $urf = <$url_fh>){
		$urff .= $urf;
		}
	
	my $kegns_fh;my @kcomps;my $rel_enz;
	if ($urff =~ /BRENDA, the Enzyme Database:(.+)ecno=(.+?)\">(.+)/){$brenda = $2;}
	if ($urff =~ /<tr><th(.*)<nobr>Name<\/nobr><\/th(.*?)solid\"><div style=\"width:\d+px;overflow:auto\">(.+?)<\/td><\/tr>$/msg){
			$rel_enz = $3;
			$rel_enz =~ s/<br>|<\/div>|;//g;
			}
	$kegns_fh = IO::String->new($rel_enz);	
	die "No String filehandle for rel_enz fh!\n" unless $kegns_fh;
	
	while (my $kcomps = <$kegns_fh>){push (@kcomps, $kcomps);}

	my $first_comp = shift(@kcomps);
	#print "First comp:\t$first_comp\n";
	
	foreach my $left (@kcomps){
		print "Other compds:\t$left\n";
		my $source4 = "KEGG";
		#send to database syns = other compds, and first one the first	
		$sth4->execute($left,$first_comp,$source4);
		print "Enzyme synonymn db population(KEGG) DONE. Syn\t$left\tRoot:\t$first_comp\n";
	}
	if($brenda){$br = $brenda}else{$br = ""}
	return ($first_comp, $br);
}



sub get_KEGG_c{
	my ($eid) = @_;
	my $urlk = "http://www.genome.jp/dbget-bin/www_bget?ec:$eid";
	my $urlfile = get($urlk);
	my $url_fh = IO::String->new($urlfile);
	die "NO String filehandle supplied for kegg enzyme fh!\n" unless $url_fh;
	
	my $urff;my $enzname;
	while (my $urf = <$url_fh>){
		$urff .= $urf;
		}
	
	my $kegnc_fh;my @kwcomps;my $first_class;my $rel_enzz;
	if ($urff =~ /<tr><th(.*)<nobr>Class<\/nobr><\/th(.*?)solid\"><div style=\"width:\d+px;overflow:auto\">(.*?)<a href=(.+?)<\/td><\/tr>$/msg){
			$rel_enzz = $3;
			$rel_enzz =~ s/<br>//g;
			}
	$rel_enzz =~ s/\n/ /g;
			
	return $rel_enzz;
}



sub getECGO{
	my ($ecno) = @_;
	my $realec = getrealEC($ecno);
	my $id1; my $term1; my $number1; my $GOterm; my $GOnum;
	unless(open(ENZEC2GO, "ec2go.txt")) {print "Could not open enzyme2go file!\n";}
	while (my $ecline = <ENZEC2GO>){
			next if $ecline =~ /!/;
			if($ecline =~ /EC:(.+) > (.+) ; (.+)/){$id1 = $1; $term1 = $2; $number1 = $3;}
			if($realec eq $id1){$GOterm = $term1; $GOnum = $number1;}
		}
	return($GOterm, $GOnum);

}


sub getrealEC{

	my ($numm)= @_;
	my $real;

	if($numm =~ /(.+)\.-\.-\.-/){$real = $1;}
	elsif($numm =~ /(.+)\.-\.-/){$real = $1;}
	elsif($numm =~ /(.+)\.-/){$real = $1;}
	else{$real = $numm;}

	return $real;
}


sub check_UMB{
	my ($react, $enzy, $prodd) = @_;
	my $checkk;
	unless(open(URCHECK, "UMBBD reactions.txt")){print "Could not open UMBBD reactions file!\n";}
	while (my $umbline = <URCHECK>){
		my @umbr = split(/\t/, $umbline);
		if(($react =~ /^\Q$umbr[1]\E$/i) && ($enzy =~ /^\Q$umbr[2]\E$/i) && ($prodd =~ /^\Q$umbr[3]\E$/i)){
		$checkk = "YES";		
		}else {$checkk = "NO";}	
	}
	return $checkk;
}
