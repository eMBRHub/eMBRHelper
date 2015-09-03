#!/usr/local/bin/perl -w
#====================================================================
#Software used during the pre- run stage of eMBRHelper,
#To populate the 'compounds' and 'comp_syns' database tables with compounds and their synonyms,
#obtained from relevant compounds databases. 
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

#prepare sql statements
my $sth = $dbh->prepare("INSERT INTO compound(comp_name, CAS_no, UMBBDc_id, PubChem_id, chEBI_id, Keggc_id, BSDc_id, description) VALUES(?,?,?,?,?,?,?,?)");
my $sth2 = $dbh->prepare("INSERT INTO compd_syns(synonymn, root_comp) VALUES (?,?)");

#umbbd compound entries
my @UMBBDcompids = get_UMBBDIDs();
	
#prepare BSD info
my $BSD_comp = "http://bsd.cme.msu.edu/jsp/ListController.jsp?object=Chemical";
my @bsdc_info = get_BSDC($BSD_comp);

my @keggcompIDs = getKEGGinfo(); #obtain relevant kegg biodeg compound in file

#processing compounds details:
foreach my $id (@UMBBDcompids){
	
	#insert Comp id, Comp name, CAS No., PubChem Id, ChebiID, ChebiDESC, KeggID, BSDC_ID, 
	my ($c_name, $c_CAS, $cPubc) = get_UMBBD_dets($id);
	my ($chebi_ident, $chebi_description) = get_CHEBI($c_name);
	my $kegg_id = get_KEGG($c_name);
	my $bsdc_idno = get_BSD_id($c_name);
	print "Sending compound info to database: $c_name\n";
	$sth->execute($c_name,$c_CAS,$id,$cPubc,$chebi_ident,$kegg_id,$bsdc_idno,$chebi_description);
	

} #end id loop

#do same for kegg biodegradation compounds; comp:name, KeggId, CAS No, PubchemID, ChebiID, BSDCId etx
foreach my $kc_id (@keggcompIDs){
	chomp $kc_id;
	my ($keggc_name, $keggCAS, $keggPubc, $keggch) = get_KEGG_dets($kc_id);
	my $bsdc_kid = get_BSD_id($keggc_name);
	my $umbbdd = "";
	my $chebidescription = "";
	print "Sending info to database: $keggc_name\n";
	$sth->execute($keggc_name,$keggCAS,$umbbdd,$keggPubc,$keggch,$kc_id,$bsdc_kid,$chebidescription);
} #end id loop for kegg


close (CHEBIFILE);
close (KEGGCOMP);

$sth->finish;
$sth2->finish;
$dbh->disconnect;


########Subroutines########

sub get_UMBBDIDs{
	my $UMBBD_utils = "http://umbbd.msi.umn.edu/servlets/pageservlet?ptype=allcomps";
	my $esearch_result = get($UMBBD_utils);

	my $comps_fh = IO::String->new($esearch_result);
	die "No String fh passed to the esearch results!\n" unless $comps_fh;

	my @compIDs;
	while (my $line = <$comps_fh>){
	if ($line =~ /.+compID\=(.+)\">.+/){
		my $compid = $1;
		push (@compIDs, $compid);
		}
	}

	return @compIDs;
}



sub prove{
	my $desc;
	my ($record) = @_;
	if ($record eq "null"){$desc = "";} else {$desc = $record;}
	return $desc;
}



sub get_UMBBD_dets{
	my ($id_num) = @_;
	my $umbbd_id; my $comp_name; my $syn; my $CAS; my $pubc; 

	my $chemical_entry = "http://umbbd.msi.umn.edu/servlets/pageservlet?ptype=c&compID=$id_num";
	my $chem_query = get($chemical_entry);
	my $string_fh = IO::String->new($chem_query);#store in filehandle
	die "No string fh passed to string_fh!\n" unless $string_fh;
	
	
	while (my $entry = <$string_fh>){
		if ($entry =~ /\<h1\>(.+)\<\/h1\>/){
			$comp_name = $1;
			$comp_name =~ s/<i>|<\/i>//g;
			}

		#synonymns
		if ($entry =~/Synonyms:(.+)\<p\>/){
			my $synonym = $1;
			my @synonyms = split (/;/, $synonym);
			
			foreach my $syn (@synonyms){
				chomp $syn;
				$syn =~ s/<i>|<\/i>//g;
				#send each to database entry: synonymn name and comp name
				print "Sending synonymn to database: $syn\n";
				$sth2->execute($syn,$comp_name);
				}
			}
		
		#CAS numbers
		if ($entry =~ /CAS Reg. (.+)\<p\>/){
			$CAS = $1;
			#print "CAS Registry No:\t$CAS\n";
			}
			
		#pubchem entries
		if ($entry =~ /\?sid=(.*)\">PubChem Substance Entry/){
			$pubc = $1;
			chomp $pubc;
			#print "PubChem Entry:\t$pubc\n";
			}
		
	} #end while loop for UMBBD information
	
	return ($comp_name, $CAS, $pubc);
}

sub get_CHEBI{
	my ($comp_name) = @_;
	chomp $comp_name;
	#chebi_id and description
	my $chebi_d;my $chebi_id; my $chebi_desc; my $chebi_data; my @chebi; my @keggchebi;
	my $kegg_ch; my $kegg_chd;
	unless(open(CHEBIFILE, "compounds_3star.tsv")) {print "Could not open chebisourcefile!\n";}

	while (my $chebi_line = <CHEBIFILE>){
		@chebi = split(/\t/,$chebi_line);
		chomp $chebi[0];
		chomp $chebi[5];
		chomp $chebi[6];
	
	if ($chebi[5] =~ /^\Q$comp_name\E$/i){
			$chebi_id = $chebi[0];
			$chebi_d = $chebi[6];
			$chebi_desc = prove($chebi_d);	#handle null entries
			last;
			} 
	} #end while chebi
	
	#return values
	if($chebi_id){return ($chebi_id, $chebi_desc);}
		else{
			unless(open(KEGGCOMP, "kegg_compoundrecords.txt")){print "Could not open kegg compounds file!\n";}
			while (my $kegg_line = <KEGGCOMP>){
			@keggchebi = split(/\t/,$kegg_line);
			chomp $keggchebi[1];
			if ($keggchebi[1] =~ /^\Q$comp_name\E$/){
				$kegg_ch = $keggchebi[4];
				chomp $kegg_ch;
				$kegg_chd = "";
				}		
			}		
		return ($kegg_ch, $kegg_chd);	
		}
	
}

sub get_BSDC{
	
	my ($bsd_comp) = @_;
	my $bsd_search = get($bsd_comp);
	my $bsd_comps_fh = IO::String->new($bsd_search);
	die "No filehandle info received for bsd!\n" unless $bsd_comps_fh;

	my @bsdc_infor; my $bsdc_id; my $bsdc_name;
	while (my $b_line = <$bsd_comps_fh>){
		if ($b_line =~ /a href=(.+)Chemical\&id=(.+)\" onMouseOver=\"self.status=\'(.+)\';(.+)true\">/){
		$bsdc_id = $2;
		$bsdc_name = $3;
		push (@bsdc_infor, ($bsdc_id."\t".$bsdc_name));
			}
		}
		
	return @bsdc_infor;
}
	
	
sub get_BSD_id{
	my ($compd_name) = @_;
	chomp $compd_name;
	my @bsdc; my $bsdc_ident;
	for (@bsdc_info){
		@bsdc = split(/\t/,$_);
	
		if ($bsdc[1] =~ /^\Q$compd_name\E$/i){
		$bsdc_ident = $bsdc[0]; 
		last;
		}
	}
	return $bsdc_ident; 

}


sub get_KEGG{
	my ($com_name) =@_;
	chomp $com_name;
	my @keggscomp;my $keggid;
	
	unless(open(KEGGCOMP, "kegg_compoundrecords.txt")){print "Could not open kegg compounds file!\n";}
	while (my $keggs_line = <KEGGCOMP>){
	@keggscomp = split(/\t/,$keggs_line);
	chomp $keggscomp[0];
	chomp $keggscomp[1];
	if ($keggscomp[1] =~ /^\Q$com_name\E$/){$keggid = $keggscomp[0];}	
	}
	return $keggid;
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
		push(@map_numbs, $kegg_numb);	
		}	 
	}

#obtain kegg compIDs
my $keggcurl; my $keggccontent; my @cnumbs;
foreach my $item (@map_numbs){
	$keggcurl = "http://www.genome.jp/dbget-bin/get_linkdb?-t+compound+path:$item";
	
	$keggccontent	= get($keggcurl);
	my $keggc_fh = IO::String->new($keggccontent);
	die "No String fh passed for Kegg reaction url\n" unless $keggc_fh;
	
	while (my $line3 = <$keggc_fh>){
		if ($line3 =~ /.+www_bget\?cpd:(.+)\">.+<\/a>/){
			my $keggc = $1;	
				
			push(@cnumbs, $keggc);  #final array containing kegg compound ids
			}
		}
		
	}
return @cnumbs;
}



sub get_KEGG_dets{
	my ($kcompno) = @_;
	chomp $kcompno;
	my @kecomp;my $keggcname; my $keggCASn; my $keggpbc; my $keggchebi; my $ke_line;
	unless(open(KEGGCOMP, "kegg_compoundrecords.txt")){print "Could not open kegg compounds file!\n";}

	while ($ke_line = <KEGGCOMP>){
		@kecomp = split(/\t/,$ke_line);
		chomp $kecomp[0];
		chomp $kecomp[1];
		chomp $kecomp[2];
		chomp $kecomp[3];
		chomp $kecomp[4];
		if ($kecomp[0] =~ /^$kcompno$/){
			$keggcname = $kecomp[1];
			$keggCASn = $kecomp[2];
			$keggpbc = $kecomp[3];
			$keggchebi = $kecomp[4];
		}	
	}
	
	return($keggcname,$keggCASn,$keggpbc,$keggchebi);
}
