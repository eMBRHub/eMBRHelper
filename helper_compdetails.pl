#!/usr/bin/perl
use strict;
use warnings;
use CGI qw( :standard );
use CGI::Carp qw( fatalsToBrowser );
use CGI::Pretty;
use DBI;
use lib '/usr/lib/perl5/site_perl/5.8.8/i386-linux-thread-multi/DBD/mysql.pm';
use GraphViz;
use IO::String;
use File::Copy;
use Fcntl; 
use Data::Dump qw[ pp ]; #perl-Data-Dump.noarch 0:1.08-3.el5
use List::Util qw[ shuffle ];
use Time::HiRes qw[ time ];


#connect to the database
my $ds = "DBI:mysql:xxxxx:localhost";#replace xxxx with database name
my $user = "root";
my $passwd = "xxxxxx"; #replace xxxx with appropriate password

my $dbh = DBI->connect($ds,$user,$passwd) || die "Cannot connect to database!!";

#create CGI object
my $cgdc = new CGI;
my $compname = $cgdc->param('compound');

#prepare query
my $query1 = q(SELECT * FROM compound WHERE comp_name LIKE ?);
my $sth = $dbh->prepare($query1); 
my $query2 = q(SELECT synonymn FROM compd_syns WHERE root_comp = ?);
my $sth2 = $dbh->prepare($query2);

#display
print	$cgdc->header;
print	$cgdc->start_html("eMBRHelper decision support - Compound details:".$compname."!");
print   $cgdc->img({-src=>'http://psbtb02.nottingham.ac.uk/logo.jpg'});
#print   $cgi->br();
print	$cgdc->h1("Compound Details:");
print   $cgdc->h3("Compound: ".$compname.".");
print   $cgdc->hr();
	#$cgdc->pre($query1);
#do image


#$sth->execute($compname);
$sth->execute( $compname);

my @query_results1; my @query_results2; my @query_resultsp; my @query_resultss; my @query_resultsbsd; my $compid; my $cas; my $umbc; my $pubc; my $chebi; my $kegg; my $bsd; my $desc;

while (my $results1 = $sth->fetchrow_arrayref()){
	$compid = $results1->[0]; 
	$cas = $results1->[2]; 
	$umbc = $results1->[3];
	$pubc = $results1->[4];
	$chebi = $results1->[5];
	$kegg = $results1->[6];
	$bsd = $results1->[7];
	$desc = $results1->[8];
	}

#do image;
my ($imagetag, $courtesy) = getimagetag($umbc, $kegg, $pubc);

print $cgdc->table({-border=>'2', cellpadding=>'0'},
		$cgdc->Tr([
			$cgdc->td($cgdc->img({-src=>$imagetag})),
			#$cgdc->td($cgdc->small("Courtesy: (c)".$courtesy))
			])
	);

print $cgdc->td($cgdc->small("Courtesy: (c)".$courtesy));

print $cgdc->br();
print $cgdc->br();
#print   $cgdc->img({-src=>'http://umbbd.ethz.ch/core/graphics/'.$umbc.'.gif'});

my $query2 = q(SELECT synonymn FROM compd_syns WHERE root_comp = ?);
my $sth2 = $dbh->prepare($query2);

#display: box 1
my $umbclink = $cgdc->a({href=>"http://umbbd.ethz.ch/servlets/pageservlet?ptype=c&compID=$umbc",-target=>'blank'}, 'UMBBD');
my $pubclink = $cgdc->a({href=>"http://pubchem.ncbi.nlm.nih.gov/summary/summary.cgi?sid=$pubc",-target=>'blank'}, 'Pubchem');
my $chebilink = $cgdc->a({href=>"http://www.ebi.ac.uk/chebi/advancedSearchFT.do?searchString=$chebi&queryBean.stars=3&queryBean.stars=-1",-target=>'blank'}, 'chEBI');
my $kegglink = $cgdc->a({href=>"http://www.genome.jp/dbget-bin/www_bget?$kegg",-target=>'blank'}, 'KEGG');
my $bsdlink = $cgdc->a({href=>"http://bsd.cme.msu.edu/jsp/InfoController.jsp?object=Chemical&id=$bsd",-target=>'blank'}, 'BSD');

push(@query_results1, $cgdc->Tr($cgdc->td({-bgcolor=>"aquamarine",}, [$cgdc->i('eMBR'). 'Compound ID']), $cgdc->td([$compid, '----'])));
push(@query_results1, $cgdc->Tr($cgdc->td({-bgcolor=>"aquamarine",}, ['CAS Number.']), $cgdc->td([$cas, '----'])));
push(@query_results1, $cgdc->Tr($cgdc->td({-bgcolor=>"aquamarine",}, ['UMBBD Equivalent.']), $cgdc->td([$umbc, $umbclink])));
push(@query_results1, $cgdc->Tr($cgdc->td({-bgcolor=>"aquamarine",}, ['PubChem Equivalent.']), $cgdc->td([$pubc, $pubclink])));
push(@query_results1, $cgdc->Tr($cgdc->td({-bgcolor=>"aquamarine",}, ['chEBI Equivalent.']), $cgdc->td([$chebi, $chebilink])));
push(@query_results1, $cgdc->Tr($cgdc->td({-bgcolor=>"aquamarine",}, ['KEGG Equivalent.']), $cgdc->td([$kegg, $kegglink])));
push(@query_results1, $cgdc->Tr($cgdc->td({-bgcolor=>"aquamarine",}, ['Biodegradative. Strain Database.']), $cgdc->td([$bsd, $bsdlink])));
push(@query_results1, $cgdc->Tr($cgdc->td({-bgcolor=>"aquamarine",}, ['Description:']), $cgdc->td([$desc, '----'])));
#push(@query_results1, $cgdc->Tr($cgdc->td({-bgcolor=>"springgreen",}, ['CAS Number.']), $cgdc->td([$cas, '----'])));
#push(@display_res, $cgh->Tr( $cgh->td([$routno,$startnode,$endnode,$steps,$further,$link2])));
#############

#process for synonyms
$sth2->execute($compname);

my $syns;
while (my $results2 = $sth2->fetchrow_arrayref()){
	$syns = $results2->[0]; 
	push (@query_results2, $cgdc->Tr($cgdc->td($syns)));
	}

#process for sustrate and products listing:

my $queryp = q(SELECT DISTINCT reaction_iden, source FROM participates_in WHERE compound_name = ? AND role = 'product');
my $sth3 = $dbh->prepare($queryp);
	$sth3->execute($compname);
	
while (my $results3 = $sth3->fetchrow_arrayref()){
	my $r_id = $results3->[0]; 
	my $src = $results3->[1];
	my $incomingp = get_rdets($r_id);
	push (@query_resultsp, $cgdc->Tr($cgdc->td([$r_id, $incomingp, $src])));
	}

my $querys = q(SELECT DISTINCT reaction_iden, source FROM participates_in WHERE compound_name = ? AND role = 'substrate');
my $sth4 = $dbh->prepare($querys);
	$sth4->execute($compname);
	
while (my $results4 = $sth4->fetchrow_arrayref()){
	my $r_ids = $results4->[0]; 
	my $srcs = $results4->[1];
	my $incomings = get_rdets($r_ids);
	push (@query_resultss, $cgdc->Tr($cgdc->td([$r_ids, $incomings, $srcs])));
	}

#BSD info box
my $querybsd = q(SELECT bsd_strain_name FROM bsd_entries WHERE bsd_strain_id IN (SELECT bsd_strain from bsdcomp_degr WHERE comp_degr LIKE ?));
my $sth5 = $dbh->prepare($querybsd);
	$sth5->execute($compname);

while (my $results5 = $sth5->fetchrow_arrayref()){
	my $strains = $results5->[0]; 
	push (@query_resultsbsd, $cgdc->Tr($cgdc->td([$strains])));
	}

###Display codes: Box 1, 2 ,3
if(!@query_results1){
	print $cgdc->p("SORRY! Primary Information on this compound not available in our current database!");
}else{
print $cgdc->table(
	{-border => '1', cellpadding => '0', cellspacing => '0', -width =>'50%'},
	$cgdc->Tr([
		$cgdc->th(['Descriptor', 'Detail', 'Link'])
		]),

		@query_results1
	);
}
print $cgdc->br();

if (!@query_results2){
	print $cgdc->b("SYNONYM(s):");
	print $cgdc->table({-border=>'0', cellpadding=>'0', cellspacing=>'0', -width =>'50%'},
		$cgdc->Tr([
			$cgdc->td('No Synonyms for "'.$compname.'" in our current database!')
			])
	);
	
}else{
	print $cgdc->b("SYNONYM(s):");
	print $cgdc->table({-border=>'0', cellpadding=>'0', cellspacing=>'0', -width =>'50%'},
		$cgdc->Tr([
			#$cgdc->th(['SYNONYM(s):'])
			]),
			@query_results2
	);


}

print $cgdc->br();
print $cgdc->br();

if (!@query_resultsp){
	print $cgdc->b("Reactions where ".$compname." is a product");
	print $cgdc->p('No Reactions available in our database where "'.$compname.'" is a product!');
	#print $cgdc->table({-border=>'1', cellpadding=>'0', cellspacing=>'0', -width =>'60%'},
	#	$cgdc->Tr([
	#		$cgdc->td('No Reactions available in our database where "'.$compname.'" is a product!')
	#		])

	#);
	
}else{
	print $cgdc->b("Reactions where ".$compname." is a product");
	print $cgdc->table({-border=>'1', cellpadding=>'0', cellspacing=>'0', -width =>'60%'},
		$cgdc->Tr([
			#$cgdc->th(["Reactions where ".$compname." is a product"]),
			$cgdc->th(['eMBR reaction ID', 'Reaction Description', 'Courtesy'])
			]),
			@query_resultsp
	);


}

print $cgdc->br();
print $cgdc->br();
if (!@query_resultss){
	print $cgdc->b("Reactions where ".$compname." is a substrate");
	print $cgdc->p('No Reactions available in our database where "'.$compname.'" is a substrate!')
	#print $cgdc->table({-border=>'1', cellpadding=>'0', cellspacing=>'0', -width =>'60%'},
	#	$cgdc->Tr([
	#		$cgdc->td('No Reactions available in our database where "'.$compname.'" is a substrate!')
	#		])
#
	#);
	
}else{
	print $cgdc->b("Reactions where ".$compname." is a substrate");
	print $cgdc->table({-border=>'1', cellpadding=>'0', cellspacing=>'0', -width =>'60%'},
		$cgdc->Tr([
			#$cgdc->th(["Reactions where ".$compname." is a substrate"]),
			$cgdc->th(['eMBR reaction ID', 'Reaction Description', 'Courtesy'])
			]),
			@query_resultss
	);
}

print $cgdc->br();
print $cgdc->br();
if (!@query_resultsbsd){
	print $cgdc->b("Microbe Strain information from Biodegradative Strain Database:");
	print $cgdc->table({-border=>'0', cellpadding=>'0', cellspacing=>'0', -width =>'50%'},
		$cgdc->Tr([
			$cgdc->td('No information from BSD for microbial degradation of "'.$compname.'" in our current database!')
			])
	);
	
}else{
	print $cgdc->b("Microbe Strain information from Biodegradative Strain Database(BSD):");
	print $cgdc->p("From BSD the following microorganisms are capable of degrading ".$compname.".");
	print $cgdc->table({-border=>'0', cellpadding=>'0', cellspacing=>'0', -width =>'50%'},
		$cgdc->Tr([
			#$cgdc->th(['SYNONYM(s):'])
			]),
			@query_resultsbsd
	);


}
############

#clean up
$sth->finish;
$sth2->finish;
$sth3->finish;
$sth4->finish;
$sth5->finish;
$dbh->disconnect;
print $cgdc->end_html;

exit;


###subs
sub get_rdets{
 	my ($id) = @_;
	my $sthp = $dbh->prepare("SELECT * FROM participates_in WHERE reaction_iden = $id");
	$sthp->execute();
	
	my $comp; my $rol; my @subs; my @prods; my $sub; my $prd;
	while (my $res = $sthp->fetchrow_arrayref()){
	$comp = $res->[1];
	$rol = $res->[2]; 
	if ($rol eq 'substrate'){push(@subs, $comp);}
	if ($rol eq 'product'){push(@prods, $comp);}
	}
	
	if (@subs != '1'){$sub = join(" + ", @subs);}else{$sub = $subs[0];}
	if (@prods != '1'){$prd = join(" + ", @prods);}else{$prd = $prods[0];}

	my $expr = "$sub ----> $prd";
	
return ($expr);
}


sub getimagetag{
	my ($u, $k, $p) = @_;
	my $imt;my $court;

	if ($u){ $imt = 'http://umbbd.ethz.ch/core/graphics/'.$u.'.gif'; $court = 'UMBBD'; }
		elsif($k){$imt = 'http://www.genome.jp/Fig/compound/'.$k.'.gif'; $court = 'KEGG'}
		elsif($p){$imt = 'http://pubchem.ncbi.nlm.nih.gov/summary/summary.cgi?cid=$p'; $court = 'PubChem'}
	

return ($imt, $court);

}
