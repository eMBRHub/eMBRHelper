#!/usr/local/bin/perl -w
#script written to update contents of reaction database with information from reactions table found not to be in the reaction database for some reason. It checks the reaction masterfile with reactions database and if any reaction (particularly the KEGG ones is not found, it reintroduces them. First it repopulates the enzymes database with the relevant information.
#Then it runs goes on to repopulate the reactions database;
#After that it uses the information as well to repopulate the participates_in dtabase.
#Chijoke Elekwachi, MyCIB, Univ of Nottingham. UK, 2010
#====================================================================
use strict;
use warnings;
use DBI;
use LWP::Simple;
use IO::String;
use lib '/usr/lib/perl5/site_perl/5.8.8/i386-linux-thread-multi/DBD/mysql.pm';

#connect to the database
my $ds = "DBI:mysql:xxxxx:localhost";#replace xxxx with database name
my $user = "root";
my $passwd = "xxxxxx"; #replace xxxx with appropriate password

my $dbh = DBI->connect($ds,$user,$passwd) || die "Cannot connect to database!!";


my $query1 = q(SELECT reaction_id FROM reactions WHERE UMBBDr_id = ? );
my $sth = $dbh->prepare($query1);

my $query2 = q(SELECT reaction_id FROM reactions WHERE Keggr_id = ? );
my $sth2 = $dbh->prepare($query2);

my $sth3 = $dbh->prepare("SELECT enzyme_id FROM enzymes WHERE enzyme_name LIKE ?");
my $sth4 = $dbh->prepare("INSERT INTO enzymes_syns(enzz_syn, root_enzy_name, source) VALUES (?,?,?)");
my $sth5 = $dbh->prepare("INSERT INTO enzymes(enzyme_name, UMBBDe_id, Kegge_id, EC_No, BRENDAe_id, GO_term, GO_no,source) VALUES(?,?,?,?,?,?,?,?)");
#my $sth6 = $dbh->prepare("INSERT INTO reactions(UMBBDr_id, Keggr_id, enzyme_ident, source) VALUES(?,?,?,?)");
my $sth7 = $dbh->prepare("UPDATE reactions SET enzyme_ident = ? WHERE UMBBDr_id = ?");
my $sth8 = $dbh->prepare("UPDATE reactions SET enzyme_ident = ? WHERE Keggr_id = ?");
#my $output = 'NEWUKMBList.txt';
 

#open(NEWUKMB, ">$output") or die "Cant't open new ukmb file for write\n\n";

unless (open(MAIN, "UKMBFinalcomp.csv")){print "Could not open main reactions file for read!!\n";}
my @info;my $source;my $umbn; my $en;
while (my $line = <MAIN>){

	my @entryline = split(/\t/, $line);
	chomp $entryline[0]; chomp $entryline[1]; chomp $entryline[2]; chomp $entryline[3]; 
	my $reactnum = $entryline[0];
	

	#obtain reaction number
	$en = enz_name($reactnum);
#	$reaID = get_reaID();
	my $eid;
	#print "$entryline[0]\t$en\tFrom file:$entryline[2]\n";
	#use appropriate subroutine to obtain enzyme name from the internet.
	next if (($en eq "No UMBBD Enzyme Supplied" || $en eq "No KEGG Enzyme Supplied" || $en eq "No Kegg enzyme supplied") && ($entryline[2] eq "No Kegg enzyme supplied" || $entryline[2] eq "No enzyme supplied" || $entryline[2] eq "Enzyme record not found"));
	
#actual processing
	if($en eq $entryline[2]){
				$eid = get_enzymeID($en);
				}
	elsif(($en =~ m/(No UMBBD Enzyme Supplied|No KEGG Enzyme Supplied|No enzyme supplied)/) && ($entryline[2] =~ m/ase/)){
	$eid = get_enzymeID($entryline[2]);
	}
	elsif(($en =~ m/ase/) && ($entryline[2] eq "No enzyme supplied" || $entryline[2] eq "No Kegg enzyme supplied" || $entryline[2] eq "Enzyme record not found")){
		$eid = get_enzymeID($en);}
	else{
		print"Inconstinstent result: $entryline[0]\t$en\t$entryline[2]\n";
		}

	print "$entryline[0]\t$en\tFrom file:$entryline[2]\t$eid\n";
	#if enzyme name supplied go to database with enzyme name and obtain enzyme id
	#update database with the appropriate enzyme id.
	if ($eid ne "null"){
		if($reactnum =~ m/^r\d+/){$sth7->execute($eid, $reactnum);} 
		if($reactnum =~ m/^R\d+/){$sth8->execute($eid, $reactnum);}
		}elsif($eid eq "null"){
			&repopulate_enz($reactnum);
			my $en2 = enz_name($reactnum);
			my $eid2 = get_enzymeID($en2);
			$sth8->execute($eid2, $reactnum);
			}
	
	
} #end while loop




sub enz_name{
	my ($no) = @_;
	my $nom;
	my $enzymeID;
	my $rel_line; my $enzyme_no;
	
	if ($no =~ m/^r\d+/){
		my $url = "http://umbbd.msi.umn.edu/servlets/pageservlet?ptype=r&reacID=$no";
		my $url_req = get($url);
		my $url_fh = IO::String->new($url_req);
		die "No String received from UMBBD reaction url!\n" unless $url_fh;

		while(my $content = <$url_fh>){
			if ($content =~ /(.+)enzymeID=(e\d+)(\">)(.+)/){
			$enzymeID = $2;
			}
		
		 }
		if($enzymeID){$nom = get_enzyme_name($enzymeID);}else{$nom = "No UMBBD Enzyme Supplied";}
	}

	if($no =~ m/^R\d+/){
		my $rxnurl = "http://www.genome.jp/dbget-bin/www_bget?$no";
		my $rxncontent = get($rxnurl);
		my $rxn_fh = IO::String->new($rxncontent);
			die "No String fh passed for kegg enzyme reaction content!\n" unless $rxn_fh;
	
		while (my $line3 = <$rxn_fh>){
		$rel_line .= $line3;
		} 

		if ($rel_line =~ /^<tr>(.+)Enzyme<\/nobr><\/th>\n(.*?)www_bget\?ec:(.*?)\">.+$/msg){
			$enzyme_no = $3;
			} 

		if($enzyme_no){ $nom = get_kegg_enzyme_name($enzyme_no);}else{$nom = "No KEGG Enzyme Supplied";}
	}
	
	
return $nom;
}

sub get_kegg_enzyme_name{
	my ($kegenzno) = @_;
	my $enz_line; my $keggenz_name;
	my $keggenzurl = "http://www.genome.jp/dbget-bin/www_bget?ec:$kegenzno";
	my $kenz_req = get($keggenzurl);
	my $kenz_fh = IO::String->new($kenz_req);
		die "No String received from UMBBD reaction url!\n" unless $kenz_fh;

	while(my $enzcontent = <$kenz_fh>){
		$enz_line .= $enzcontent;
		}
 	if ($enz_line =~ /^<tr>(.+)Name<\/nobr><\/th>\n(.*?)overflow:auto\">(.+?)<\/td><\/tr>$/msg){
		my $keggenz_block = $3;
		$keggenz_name = clean_keg_enz($keggenz_block);
		}
		elsif($enz_line =~ /^<tr>(.+)Class<\/nobr><\/th>\n(.*?)overflow:auto\">(.+?)<a href\=\".+<\/tr>$/msg){
			my $keggclass_block = $3;
			$keggenz_name = clean_keg_enz($keggclass_block);
		}  
	return $keggenz_name;
}

sub get_enzyme_name{
	my($enzymeID) = @_;
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

sub clean_keg_enz{
	my ($block) = @_;
	$block =~ s/<br>|<\/div>//g;
	my @block_content = split(/;/, $block);
	my $clean = $block_content[0];
	return $clean;
}



sub is_inreact{

 my ($numb) = @_;
 my $id; my @um; my $ent;my $r;
	if ($numb =~ m/^r\d+/){
	$sth->execute($numb);

	while (my $result = $sth->fetchrow_arrayref()){
		 $id = $result->[0];
		 $ent = "$numb^^$id";
		push (@um, $ent);
		}
	}elsif ($numb =~ m/^Rd+/){
		$sth2->execute($numb);
		while (my $result2 = $sth2->fetchrow_arrayref()){
		$id = $result2->[0];
		$ent = "$numb^^$id";
		push (@um, $ent);
		}
	}

	my $ret = join(";", @um);
	if ($ret){ $r = $ret}else{$r = "NULL";}
return $r;
}

sub get_enzymeID{
	my ($umrx_name) = @_;
	my $n;
	$sth3->execute($umrx_name);

	my @result3 = $sth3->fetchrow_array();
	my $enumb = $result3[0];
	if($enumb){$n = $enumb;} else{$n = "null";}
	return $n;
	
}

sub checkUMBBD{
	my ($a, $b, $c) = @_;
	my $match;
	unless(open(UMBBDR, "UMBBD reactions.txt")) {print "Could not open umbbdreactions file to check\n";}
	
	while (my $r_line = <UMBBDR>){
	next if $r_line =~ /Reaction/;
	my @rinfo = split(/\t/, $r_line);chomp $rinfo[0]; chomp $rinfo[1]; chomp $rinfo[2]; chomp $rinfo[3];
	#print "$a----$rinfo[1]\t$b----$rinfo[2]\t$c----$rinfo[3]\n";
	if ($rinfo[1] eq $a && $rinfo[2] eq $b && $rinfo[3] eq $c){ $match = $rinfo[0];}else{$match = "NOT MATCHED";}
	
	} #print "One Ended: Next\n\n\n\n";
	return $match;
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
	#if ($enzll =~ /BRENDA, the Enzyme Database:(.+)ecno=(.+?)\">(.+)/){$brenda = $2;}
	if ($enzll =~ /<tr><th(.*)<nobr>Enzyme<\/nobr><\/th(.*?)dbget-bin\/www_bget\?ec:(.+?)\">(.+?)<\/td><\/tr>$/msg){
			$enz_idd = $3;
			$enz_idd =~ s/<br>|<\/div>|;//g;
			#print "Enzyme id:\t$enz_idd\n";
			#$kegns_fh = IO::String->new($rel_enz);
			}
		
	
	#get the enzyme records:
	if($enz_idd){
	($keggen_name, $bbrenda_id) = get_KEGG_d($enz_idd);
	#print "Enzyme name:\t$keggen_name\nBrenda:\t$bbrenda_id\n";
	if($keggen_name){
		$keggenzyme = $keggen_name;		
	}else{$keggenzyme = get_KEGG_c($enz_idd);} #print "New Enzymename: \t$keggenzyme\n";

	#print "Kegg enzyme\t$keggenzyme\n";
	my $k_number = "ec:"."$enz_idd";
	my $umb_enz_no = "NO UMBBD enzyme record"; #bc enzyme name is unique in db. this will only be inserted if not.
	#get keggno GO and Go number
	my ($kontolt, $kontoln) = getECGO($enz_idd);
	my $source3 = "KEGG";
	#print "Kegg Records: $keggenzyme\t$umb_enz_no\t$k_number\t$enz_idd\t$bbrenda_id\t$kontolt\t$kontoln\n";
	$sth5->execute($keggenzyme,$umb_enz_no,$k_number,$enz_idd,$bbrenda_id,$kontolt,$kontoln,$source3);
	print "=============>Populating enzyme database: KEGG records: DONE. Enzyme:\t$keggenzyme\n";
	}
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
	
	my $kegns_fh;my @kcomps; my $rel_enz;
	if ($urff =~ /BRENDA, the Enzyme Database:(.+)ecno=(.+?)\">(.+)/){$brenda = $2;}
	if ($urff =~ /<tr><th(.*)<nobr>Name<\/nobr><\/th(.*?)solid\"><div style=\"width:\d+px;overflow:auto\">(.+?)<\/td><\/tr>$/msg){
			$rel_enz = $3;
			$rel_enz =~ s/<br>|<\/div>|;//g;
			print "$rel_enz\n";
			#$kegns_fh = IO::String->new($rel_enz);
			}

	$kegns_fh = IO::String->new($rel_enz);	
	die "No String filehandle for rel_enz fh!\n" unless $kegns_fh;
	
	while (my $kcomp = <$kegns_fh>){push (@kcomps, $kcomp);}
	#print "Contents: enzymes\t@kcomps\n";
	my $first_comp = shift(@kcomps);
#	print "First comp:\t$first_comp\n";
	
	foreach my $left (@kcomps){
#		print "Other compds:\t$left\n";
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
			#print "REal enz:\t$rel_enz";
			$rel_enzz =~ s/<br>//g;
			#print "$rel_enzz\n";
			#$kegnc_fh = IO::String->new($rel_enz);
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
