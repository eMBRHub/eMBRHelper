#!/usr/local/bin/perl -w
#====================================================================
#Software used during the pre- run stage of eMBRHelper,
#To populate the 'enzymes' and 'enzymes_syns'(synonyms) database tables
#using information primarily obtained from UMBBD
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

#prepare sql statements
my $sth = $dbh->prepare("INSERT INTO enzymes(enzyme_name, UMBBDe_id, Kegge_id, EC_No, BRENDAe_id, GO_term, GO_no,source) VALUES(?,?,?,?,?,?,?,?)");
my $sth2 = $dbh->prepare("INSERT INTO enzymes_syns(enzz_syn, root_enzy_name, source) VALUES (?,?,?)");

#umbbd compound entries
my $UMBBD_enzyme = "http://umbbd.msi.umn.edu/servlets/pageservlet?ptype=allenzymes";
my $enzyme_result = get($UMBBD_enzyme);

my $enzymeID_fh = IO::String->new($enzyme_result);
die "No String fh passed to the esearch results!\n" unless $enzymeID_fh;

#umbbd enzyme entries
my $enzy_ec_no;my $uenzy_id; my $enzy_name;my $ontolt; my $ontoln;my $source = "UMBBD";
open (NAMESTORE, ">>umbbd_enz_name_storage.txt") or die "Can't open file for write $!\n"; 
#a name store necessary so as to prevent double entries when KEGG enzyme records are subsequently included

while (my $eline = <$enzymeID_fh>){
	if ($eline =~ /<tr><td>(.+)<\/td><td>(.+)enzymeID=(.+)\">(.+) \(enzymeID\#.+/){
		$enzy_ec_no = $1; #ec no
		$uenzy_id = $3; #enzyme id
		$enzy_name = $4; #enzyme name
		$enzy_name =~ s/<i>|<\/i>//g;
		my ($kegg, $brenda) = get_keggbreno($uenzy_id);#kegg no and brenda no
		my ($GO, $GO_no) = get_UMBBDGO($uenzy_id);
		if($GO){$ontolt = $GO;
			$ontoln = $GO_no;
			}else{($ontolt, $ontoln) = getECGO($enzy_ec_no);}
		$sth->execute($enzy_name,$uenzy_id,$kegg,$enzy_ec_no,$brenda,$ontolt,$ontoln,$source);
		print "=============>Populating enzyme database: UMBBD records: DONE. Enzyme:\t$enzy_name\n"; 
		print NAMESTORE "$enzy_name\n";
		}

}

#same for kegg entries: on feeding into database, the 'unique' fields eliminate others
my @keggenz_nos = getKEGGinfo();
my $kegge_name; my $kegg_class; my $umb_enz_no; my $kegge_no, my $kegg_ec;my $keggenzyme;my $brenda_id;
my $source2 ="KEGG";

foreach my $enz_id (@keggenz_nos){
	($kegge_name, $brenda_id) = get_KEGG_d($enz_id);
	#if no kegg record then obtain the class
	if($kegge_name){
		$keggenzyme = $kegge_name;		
	}else{$keggenzyme = get_KEGG_c($enz_id);}
	
	$umb_enz_no = "NO UMBBD enzyme record"; #bc enzyme name is unique in db. this will only be inserted if not.
	$kegge_no = $enz_id;
	
	if ($enz_id =~ /ec:(.+)/){$kegg_ec = $1;}
	#get keggno GO and Go number
	my ($kontolt, $kontoln) = getECGO($kegg_ec);
	my $check = check_name($keggenzyme);
	if ($check eq "NO"){
	$sth->execute($keggenzyme,$umb_enz_no,$kegge_no,$kegg_ec,$brenda_id,$kontolt,$kontoln,$source2);
	print "=============>Populating enzyme database: KEGG records: DONE. Enzyme:\t$keggenzyme\n" 
		}
	}

close (NAMESTORE);
$sth->finish;
$sth2->finish;
$dbh->disconnect;


#==============================================
#subroutines#
#==============================================

sub get_KEGG_d{
	my ($eid) = @_;
	my $urlk = "http://www.genome.jp/dbget-bin/www_bget?$eid";
	my $urlfile = get($urlk);
	my $url_fh = IO::String->new($urlfile);
	die "NO String filehandle supplied for kegg enzyme fh!\n" unless $url_fh;
	
	my $urff;my $enzname;my $brenda;my $br;my $source3 = "KEGG";
	while (my $urf = <$url_fh>){
		$urff .= $urf;
		}
	
	my $kegns_fh;my @kcomps; my $rel_enz;
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
		#print "Other compds:\t$left\n";
		#send to database syns = other compds, and first one the first	
		$sth2->execute($left,$first_comp,$source3);
		print "Enzyme synonymn db population(KEGG) DONE. Syn\t$left\tRoot:\t$first_comp\n";
	}
	if($brenda){$br = $brenda}else{$br = ""}
	return ($first_comp, $br);
}

sub get_KEGG_c{
	my ($eid) = @_;
	my $urlk = "http://www.genome.jp/dbget-bin/www_bget?$eid";
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
			#print "REal enz:\t$rel_enz";
			$rel_enzz =~ s/<br>//g;
			#print "$rel_enzz\n";
			}
	$rel_enzz =~ s/\n/ /g;
			
	return $rel_enzz;
}


sub get_keggbreno{
	my ($enzz) = @_;
	my $kegge_no; my $k; my $namee;my $brend;my $b;my $esyns;my $source4 = "UMBBD";
	my $Uenz_url = "http://umbbd.msi.umn.edu/servlets/pageservlet?ptype=ep&enzymeID=$enzz";
	my $sp_enz_res = get($Uenz_url);
	my $sp_enz_fh = IO::String->new($sp_enz_res);
	die "NO String filehandle passed for UMBBD enzyme entry!!\n" unless $sp_enz_fh;
	
	while (my $enfh = <$sp_enz_fh>)
	{


		if ($enfh =~ /<a href=(.+)bget\?(.+)\">Kyoto.+/){
			$kegge_no = $2;
			}
	
		if ($enfh =~ /<li>Reactions catalyzed by <b>(.+)<\/b>/){
			$namee = $1; # enzyme name
			$namee =~ s/<i>|<\/i>//g;
			}

		if ($enfh =~ /<li>(.+)ecno=(.+)\">BRENDA<\/a>/){
			$brend = $2;
			}

		if($enfh =~ /<li>Synonyms:(.+)<p>/)
			{
			$esyns = $1;
			next unless defined($esyns);
			#print "Synonyms:\t$esyns\n";
			}
	} #end while loop
	
	#process synonyms	
		if ((defined($esyns)) && ($esyns =~ /;/))
			{
			my @esynss = split(/;/,$esyns);
			foreach my $one (@esynss){  #print "Enzyme syns: $one\n";
			$sth2->execute($one,$namee,$source4);
			print "Enzyme synonymn db population(UMBBD): Syn\t$one\tRoot:\t$namee\tDONE\n";
							}
			}elsif((defined($esyns)) && ($esyns !~ /;/))
				{ #print "The only enzyme syn: $esyns\n";
				$sth2->execute($esyns,$namee,$source4);
				print "Enzyme synonymn db population(UMBBD): Syn\t$esyns\tRoot:\t$namee\tDONE\n";
					}
	
			
	
					
			
#organise returns 
if($kegge_no){$k = $kegge_no;} else{$k = "";}
if($brend){$b = $brend;}else{$b = "";}

return ($k, $b);
}


sub getKEGGinfo{

my $KEGG_html = "http://www.genome.jp/kegg/pathway.html";
my $kegg_result = get($KEGG_html);

my $kegID_fh = IO::String->new($kegg_result);
die "No String fh passed to the keggsearch results!\n" unless $kegID_fh;

my $section; my $rel_section;my $kegg_numb; my @map_numbs;my $kegg_num;
while (my $kline = <$kegID_fh>){
	$section .= $kline;
	}
	if ($section =~ /.*Xenobiotics Biodegradation and Metabolism<\/b>(.+?)<\/table>.*/msg){
		$rel_section = $1;
		}
	my $mapno_fh = IO::String->new($rel_section);


#kegg id nums
while (my $map_numb = <$mapno_fh>){
	
	if ($map_numb =~ /.+\/.ap\/(.+).html\">(.+)<\/a>/){
		$kegg_numb = $1;  #ie kegg map numbers
		#print "kegg number now:$kegg_numb\n";
		#$keggpathname= $2;
		push(@map_numbs, $kegg_numb);	
		}	 
	}

#obtain kegg compIDs
my $keggeurl; my $keggecontent; my @enumbs;
foreach my $item (@map_numbs){
	$keggeurl = "http://www.genome.jp/dbget-bin/get_linkdb?-t+enzyme+path:$item";
	#print " Got to item no : $item\n";
	$keggecontent	= get($keggeurl);
	my $kegge_fh = IO::String->new($keggecontent);
	die "No String fh passed for Kegg reaction url\n" unless $kegge_fh;
	
	while (my $line4 = <$kegge_fh>){
		if ($line4 =~ /.+www_bget\?(.+)\">.+<\/a>/){
			my $kegge = $1;	
			push(@enumbs, $kegge);  #final array containing kegg enzyme ids
			}
		}
		
	}
return @enumbs;
}

sub get_UMBBDGO{
	my ($umbbdeid) = @_;
	my $id; my $term; my $number;my $GOt; my $GOn;
	
	unless(open(UMBBDENZYME2GO, "um-bbd_enzymeid2go.txt")) {print "Could not open umbbd2go file!\n";}

	while (my $goline = <UMBBDENZYME2GO>){
		next if $goline =~ /!/;
		if ($goline =~ /UM-BBD_enzymeID:(.+) > (.+) ; (.+)/){$id = $1; $term = $2; $number = $3;}
		if ($id eq $umbbdeid){#print "Go Term:\t$term\nGO Numb:\t$number\n";
					$GOt = $term;
					$GOn = $number;
			}
		
	}
	return ($GOt,$GOn);

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


sub check_name{
	my ($in)= @_;
	my $contain;my $found;my $a = "YES"; my $b = "NO";
	unless(open(NAMESTORE, "umbbd_enz_name_storage.txt")) {print "Couldn't open namestorage file\n";}

	while (my $enzylinee = <NAMESTORE>){
		chomp $enzylinee;
		#print "$enzylinee\n";
		if ($enzylinee =~ /^$in$/i){$contain = $a; 
			#print "Contain: $contain\n";
			last;
		}else{$contain = $b;}	
	}
	
	return $contain;
}
