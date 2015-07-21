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
use Text::Wrap;
$Text::Wrap::columns = 60;


#connect to the database
my $ds = "DBI:mysql:eMBR_helper:localhost";
my $user = "root";
my $passwd = "S952pa74lkp";
my $dbh = DBI->connect($ds,$user,$passwd) || die "Cannot connect to database!!";


my $sth = $dbh->prepare("SELECT GO_desc, GO_num FROM umbbd_go WHERE umbbdr_ident = ?");
my $sth2 = $dbh->prepare("SELECT GO_descr, GO_number FROM kegg_go WHERE keggr_ident = ?");
my $sth3 = $dbh->prepare("SELECT pathw_name  FROM deg_pathways WHERE deg_pathw_id IN (SELECT degpathID from rxn_pathw WHERE reactionID IN (SELECT reaction_id FROM reactions WHERE UMBBDr_id = ? AND reaction_id =?))");
my $sth4 = $dbh->prepare("SELECT initiating_micr  FROM deg_pathways WHERE pathw_name = ? AND deg_pathw_id IN (SELECT degpathID from rxn_pathw WHERE reactionID IN (SELECT reaction_id FROM reactions WHERE UMBBDr_id = ? AND reaction_id =?))");
my $sth5 = $dbh->prepare("SELECT pathw_descr FROM deg_pathways WHERE pathw_name = ? AND deg_pathw_id IN (SELECT degpathID from rxn_pathw WHERE reactionID IN (SELECT reaction_id FROM reactions WHERE UMBBDr_id = ? AND reaction_id =?))");
my $sth6 = $dbh->prepare("SELECT umbbdpath_id FROM deg_pathways WHERE pathw_name = ? AND deg_pathw_id IN (SELECT degpathID from rxn_pathw WHERE reactionID IN (SELECT reaction_id FROM reactions WHERE UMBBDr_id = ? AND reaction_id =?))");
my $sth7 = $dbh->prepare("SELECT * FROM enzymes WHERE enzyme_id IN (SELECT enzyme_ident FROM reactions WHERE reaction_id = ?)");
my $sth8 = $dbh->prepare("SELECT * FROM enzymes WHERE enzyme_id IN (SELECT enzyme_ident FROM reactions WHERE reaction_id = ?)");

#create CGI object
my $cgdd = new CGI;
my $edgedets = $cgdd->param('rxndets');
my $from =$cgdd->param('from');
my $to = $cgdd->param('to');
my $compound = $cgdd->param('compound');
my $rout = $cgdd->param('route');
my $degstep = $cgdd->param('rxnstep');

print	$cgdd->header;
print	$cgdd->start_html("eMBRHelper decision support - Path details: ".$compound." degradation. ".$rout." - ".$from."--to--".$to."!");
print   $cgdd->img({-src=>'http://psbtb02.nottingham.ac.uk/logo.jpg'});
print	$cgdd->h1("Breakdown of Path Details:");
print   $cgdd->h3("Compound: ".$compound."; ".$rout."; Step ".$degstep.".");

my $myself = $cgdd->self_url;
print $cgdd->ul(
	$cgdd->li($cgdd->a({href=>"\#reactinfo"},'Reaction/Pathway Info.')), 
	$cgdd->li($cgdd->a({href=>"\#enzymeinfo"},'Enzyme Info.')), 
	$cgdd->li($cgdd->a({href=>"\#microbeinfo"},'Microbe Info.'))
	);
print   $cgdd->hr();

print   $cgdd->h2({id=>'reactinfo'},"REACTION/PATHWAY:");
print $cgdd->h3("Reaction: ".$from. "  ----->  ".$to);

my $umk; my $enz; my $reac_id;
if($edgedets !~ m/;/){
	($umk, $enz, $reac_id) = brk_dets($edgedets); 
	print $cgdd->p($cgdd->i("eMBR"). "Reaction ID: ".$reac_id);

	if($umk =~ m/^r\d+/){print $cgdd->p("UMBBD: ".$umk);
				print $cgdd->p("KEGG: No KEGG Equivalent");
	}elsif($umk =~ m/^R\d+/){
				print $cgdd->p("KEGG: ".$umk);
				print $cgdd->p("UMBBD: No UMBBD Equivalent");
			 	}
	}
elsif($edgedets =~ m/;/){
			my @bits = split (/;/, $edgedets);
			foreach my $bit (@bits){
			($umk, $enz, $reac_id) = brk_dets($bit); 
			if($umk =~ m/^r\d+/){print $cgdd->p("UMBBD: ".$umk);
					print $cgdd->p("KEGG: No KEGG Equivalent");
			}elsif($umk =~ m/^R\d+/){
					print $cgdd->p("KEGG: ".$umk);
					print $cgdd->p("UMBBD: No UMBBD Equivalent");
			 		}
			}

}
#do image;
print $cgdd->br();
print $cgdd->b("Reaction Graphic:"); 
my ($imagetag, $courtesy) = getimagetag($umk);

print $cgdd->table({-border=>'2', cellpadding=>'0'},
		$cgdd->Tr([
			$cgdd->td($cgdd->img({-src=>$imagetag})),
			])
	);
print $cgdd->td($cgdd->small("Courtesy: (c)".$courtesy));
#print  $cgd->p("Contents:\t".$contents);
print $cgdd->br();
print $cgdd->br();
print $cgdd->br();
print $cgdd->br();
#add GO information
print $cgdd->b("Gene Ontology Information available for this reaction:");
my ($go_term, $go_numb) = get_go($umk);
	#print $cgdd->p("UMK at this time = $umk");
 if($go_term){print $cgdd->p("Gene Ontology Accession: ".$go_numb.".");}else{print $cgdd->p("GO Accession not available for this reaction.");} 
 if($go_numb){print $cgdd->p("Gene Ontology Term: ".$go_term.".");}else{print $cgdd->p("GO Term not available for this reaction.");}

print $cgdd->br();
print $cgdd->br();		
#add pathway info
print $cgdd->b("Pathway information available for reaction:");
my @rep;my $pathn;my $initmic;my $desc; my $pidd;my $umblink;my @pathss; my $kglink;my $kglink2;my $link;

if($umk =~ m/^r\d+/){

	$sth3->execute($umk,$reac_id);
	while (my $pth = $sth3->fetchrow_arrayref()){
			$pathn = $pth->[0]; 
			push(@rep, $pathn);
			}
	my @pnames = get_pname(@rep);

	if (@pnames == 1){
		print $cgdd->p("This reaction is involved in the ".$cgdd->b($pnames[0]).".----(UMBBD)");
		$initmic = get_microbes($umk, $reac_id, $pnames[0]);
		$desc = get_desc($umk, $reac_id, $pnames[0]);
		$umblink = get_linkid($umk, $reac_id, $pnames[0]);
		if($umblink){$link = $cgdd->a({-href=>"http://umbbd.ethz.ch/$umblink/".$umblink."_map.html"}, "UMBBD");}
		push(@pathss, $cgdd->Tr( $cgdd->td([ $pnames[0],$initmic, $desc, $link])));
	}
	elsif(@pnames > 1){my $ns = join(" and ", @pnames); 
		print $cgdd->p("This reaction is involved in the ".$cgdd->b($ns).".----(UMBBD)");
		foreach (@pnames){
		$initmic = get_microbes($umk, $reac_id, $_);
		$desc = get_desc($umk, $reac_id, $_);
		$umblink = get_linkid($umk, $reac_id, $_);
		if($umblink){$link = $cgdd->a({-href=>"http://umbbd.ethz.ch/$umblink/".$umblink."_map.html"}, "UMBBD");}
		push(@pathss, $cgdd->Tr( $cgdd->td([$_,$initmic, $desc, $link])));
					}
	}
}elsif($umk =~ m/^R\d+/){
	my @kegg_dets2 = get_keggd($umk);
	my @k_names = get_knames($umk);
	
	if (@kegg_dets2==1){
		my @lconts = split (/\t/, $kegg_dets2[0]);
		print $cgdd->p("This reaction is involved in the ".$cgdd->b($lconts[1])." pathway.----(KEGG)");
		my $mpno = $lconts[0];				
		$mpno =~ s/"map"/"rn"/g;
	
		$kglink = $cgdd->a({-href=>"http://www.genome.jp/kegg-bin/show_pathway?$mpno+$umk"}, "KEGG");
		push (@pathss, $cgdd->Tr($cgdd->td([$lconts[1],"Not Yet Available", "Not Yet Available", $kglink])));
	
	}
	elsif(@kegg_dets2>1){
		my $headbreak = join(" and ", @k_names);
		print $cgdd->p("This reaction is involved in the ". $cgdd->b($headbreak)." pathways----(KEGG)");
			
		foreach my $entry (@kegg_dets2){
		my @lconts2 = split(/\t/, $entry);
		my $mpno = $lconts2[0];
		$mpno =~ s/"map"/"rn"/g;
		$kglink2 = $cgdd->a({-href=>"http://www.genome.jp/kegg-bin/show_pathway?$mpno+$umk"}, "KEGG");
		push (@pathss, $cgdd->Tr($cgdd->td([$lconts2[1],"Not Yet Available", "Not Yet Available", $kglink2])));
		}
	
	}


}

#print
#print $cgdd->p("Contents of pathsss: @pathss");
if(!@pathss){
		print $cgdd->p("No pathway information in our current database!");
		}else{
			print $cgdd->table(
			{-border => '1', cellpadding => '1', cellspacing => '1'},
			$cgdd->Tr([
				$cgdd->th(['Pathway', 'Initiating Microbes', 'Description', 'Link'])
				]),

				@pathss
			);
		}


print   $cgdd->br();
print   $cgdd->br();
print   $cgdd->hr();
print $cgdd->h2({-id=>'enzymeinfo'}, "ENZYME INFO:");
print $cgdd->h4("Reaction: ".$from. "  ----->  ".$to);

print $cgdd->p("Reaction catalyzed by:");
my @enzd = get_enzymedets($reac_id);
my ($e_id, $e_name) = get_no_name($reac_id);

print $cgdd->table({-border=>'1', cellpadding=>'0', cellspacing=>'0', -width =>'60%'},
		$cgdd->Tr([
			#$cgdc->th(['SYNONYM(s):'])
			]),
			@enzd
	);

my @enzrids = exz_reactions($e_id);
print   $cgdd->br();
if(!@enzrids){
		print $cgdd->p("All reactions catalyzed by ".$cgdd->b($e_name)."!");
		print $cgdd->p("No Reactions found in database!");
		}else{
			print $cgdd->p("All reactions catalyzed by ".$cgdd->b($e_name)."!");
			print $cgdd->table(
			{-border => '1', cellpadding => '1', cellspacing => '1'},
			$cgdd->Tr([
				$cgdd->th(['Reaction ID', ' From ', ' To ', 'Pathway(s)'])
				]),

				@enzrids
			);
		}


print   $cgdd->hr();
print $cgdd->h2({-id=>"microbeinfo"},"MICROBE INFO:");
print $cgdd->h4("Enzyme: ".$cgdd->b($e_name).". Microorganism(s) where found:");

my @enzymicr = enzy_micro($e_name);
my @enzymicr2 = get_pname(@enzymicr); 
my $arrsize = @enzymicr2;

if(!@enzymicr2){
		print $cgdd->p("No Microorganism information found in database for the enzyme!");
		}else{
			print $cgdd->table(
			{-border => '1', cellpadding => '1', cellspacing => '1'},
			$cgdd->Tr([
				$cgdd->th({-bgcolor=>"aquamarine", -font size=>"4",},['Enzyme', 'Microbe', 'Protein Sequence', 'No. of bases', 'Source'])
				]),

				@enzymicr2
			);
		print $cgdd->small("Only first $arrsize record(s) shown.");
		}

#print $cgdd->br;
print $cgdd->br;
print $cgdd->b("To view all records and(or) to query the database use form below. TO query database for specific term use 'ALL' in corresponding textfield");
print $cgdd->br;
print $cgdd->start_form(-action => "http://psbtb02.nottingham.ac.uk/cgi-bin/microbedata.pl",  -method => "get");
print $cgdd->textfield(
	-name => "EnzymeName",
	-default => "Enzyme Name",
	-size => "30"
	);

print $cgdd->textfield(
	-name => "Microorganism",
	-default=> "Microorganisms(ALL)",
	-size => "30"
	);

print $cgdd->submit; print $cgdd->reset;
print $cgdd->end_form();

#clean up
$sth->finish;
$sth2->finish;
$sth3->finish;
$sth4->finish;
$sth5->finish;
$sth6->finish;
$sth7->finish;
$dbh->disconnect;
print $cgdd->end_html;

exit;



###subs
sub enzy_micro{
	my ($en, $eid) =@_;
	my @enzmicro;my $nam; my $micm; my $prt; my $nb; my $ss; my $prtw;my $fasta;my $fprtw;
	my $sthem = $dbh->prepare("SELECT * FROM enzyme_in WHERE enzymeName = ? ORDER BY no_of_bases LIMIT 0,12"); 
	$sthem->execute($en);

	while (my $emics = $sthem->fetchrow_arrayref()){
		$nam = $emics->[2];
		$micm = $emics->[3];
		$fasta = $emics->[5];
		$prt = $emics->[6]; $prtw = wrap('', '', $prt);
		$fprtw = "$fasta\n$prtw";
		$nb = $emics->[4];
		$ss= $emics->[7];
		push(@enzmicro, $cgdd->Tr($cgdd->td([$nam, $micm, $fprtw,$nb,$ss])));
		}

return @enzmicro;
$sthem->finish;
}
sub exz_reactions{
	my ($ei) = @_;
	my $reac; my $umbbr; my $kgr; my $sr; my @reactpath;
	my $sthee = $dbh->prepare("SELECT * FROM reactions WHERE enzyme_ident = ?"); 
	$sthee->execute($ei);

	while (my $edets = $sthee->fetchrow_arrayref()){
		$reac = $edets->[0];
		$umbbr = $edets->[1];
		$kgr = $edets->[2];
		$sr = $edets->[6];
		
		my $fromto = get_rdets($reac);
		my @frmt = split (/ ----> /, $fromto);
		my $frm = $frmt[0]; chomp $frm;
		my $to = $frmt[1]; chomp $to;

		my $pathway = get_paths($ei, $reac, $umbbr, $kgr, $sr);
		
		push(@reactpath, $cgdd->Tr($cgdd->td([$reac, $frm, $to, $pathway])));
		}

return @reactpath;
$sthee->finish;	
}

sub get_paths{
	my ($e, $r, $u, $k, $s) =@_;
	my $name; my $pid; my @path; my $pthwlink; my @path2; my $pathwa; my $sthpw;

	if ($s eq "UMBBD" || $s eq "UMBBD/KEGG"){
	
		$sthpw = $dbh->prepare("SELECT pathw_name, umbbdpath_id FROM deg_pathways WHERE deg_pathw_id IN (SELECT degpathID from rxn_pathw WHERE reactionID IN (SELECT reaction_id FROM reactions WHERE UMBBDr_id = ? AND reaction_id =?))");
		$sthpw->execute($u, $r);		

		while (my $pathw = $sthpw->fetchrow_arrayref()){
			$name = $pathw->[0];
			$name =~ s/Pathway//g;
			$pid = $pathw->[1];chomp $pid;
			$pthwlink = $cgdd->a({-href=>"http://umbbd.ethz.ch/$pid/".$pid."_map.html"}, "$name");
			push (@path, $pthwlink);
			}
			@path2 = get_pname(@path);
			if (@path2 == 1){$pathwa = $path2[0];}elsif(@path2>1){$pathwa = join(",\n", @path2);}
	}elsif($s eq "KEGG"){
		my @kpath = get_keggd($k);

		foreach my $line6 (@kpath){
			my @keggpathf = split(/\t/, $line6);
			my $mp = $keggpathf[0];
			$mp =~ s/"map"/"rn"/g;
			my $pnm = $keggpathf[1];
			$pthwlink = $cgdd->a({-href=>"http://www.genome.jp/kegg-bin/show_pathway?$mp+$k"}, "$pnm");
			push(@path, $pthwlink);
			}
			@path2 = get_pname(@path);
			if (@path2 == 1){$pathwa = $path2[0];}elsif(@path2>1){$pathwa = join(",\n", @path2);}
	
	}else{$pathwa = "None";}

return $pathwa;
$sthpw->finish;
}

sub get_no_name{
	my ($i) = @_;
	my $id; my $na;
	my $sthnn = $dbh->prepare("SELECT enzyme_id, enzyme_name FROM enzymes WHERE enzyme_id IN (SELECT enzyme_ident FROM reactions WHERE reaction_id = $i)");
	$sthnn->execute();
	
	while (my $noname = $sthnn->fetchrow_arrayref()){
		$id = $noname->[0];
		$na = $noname->[1];
		}
	
return ($id, $na);
$sthnn->finish;	
}

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
$sthp->finish;
}


sub get_enzymedets{
	my ($reid) = @_;
	my $kglink; my $brlink; my $ublink;my $ezn;my $ename; my $ec;my $gotrm;my $gono;my $umbb;my $kgee;my $brd;
	my @enz_results;

	$sth7->execute($reid);
	while (my $ezm = $sth7->fetchrow_arrayref()){
		 $ezn = $ezm->[0];
		 $ename= $ezm->[1]; 
		 $ec = $ezm->[4];
		 $gotrm = $ezm->[6];
		 $gono = $ezm->[7];
		 $umbb = $ezm->[2];
		 $kgee = $ezm->[3];
		 $brd = $ezm->[5];
		if($kgee){$kglink = $cgdd->a({href=>"http://www.genome.jp/dbget-bin/www_bget?$kgee", -target=>'blank'}, 'KEGG');}else{$kglink = "NO KEGG";}
		if($brd){$brlink = $cgdd->a({href=>"http://www.brenda-enzymes.info/php/result_flat.php4?ecno=$brd", -target=>'blank'}, 'BRENDA');}else{$brlink = "NO BRENDA";}
		if($umbb){$ublink = $cgdd->a({href=>"http://umbbd.ethz.ch/servlets/pageservlet?ptype=ep&enzymeID=$umbb", -target=>'blank'}, 'UMBBD');}else{$ublink="NO UMBBD";}

		}

	if(!$ezn){
		push(@enz_results,$cgdd->Tr([$cgdd->td('Enzyme Information Not Available')]));}
	else{
	push(@enz_results, $cgdd->Tr($cgdd->td({-bgcolor=>"aquamarine",}, ['Enzyme Name']), $cgdd->td([$ename])));
	push(@enz_results, $cgdd->Tr($cgdd->td({-bgcolor=>"aquamarine",}, ['EC Number']), $cgdd->td([$ec])));
	push(@enz_results, $cgdd->Tr([$cgdd->td('Gene Ontology Info. for Enzyme Action')]));
	push(@enz_results, $cgdd->Tr($cgdd->td({-bgcolor=>"aquamarine",}, ['GO Term/Desc.']), $cgdd->td([$gotrm])));
	push(@enz_results, $cgdd->Tr($cgdd->td({-bgcolor=>"aquamarine",}, ['GO Number']), $cgdd->td([$gono])));
	push(@enz_results, $cgdd->Tr($cgdd->td({-bgcolor=>"aquamarine",}, ['Other Links']), $cgdd->td([$ublink.",\n".$kglink.",\n".$brlink])));
	}


return @enz_results;
}


sub get_knames{
my ($kr_numb)= @_;
my @knames;
unless(open(KGRR, "/var/www/html/kegg_mapno_paths_reactions.txt")) {print "Could not open keggmapinfo file for pathway check\n";}
	
	while (my $k_line = <KGRR>){
	#print $cgdd->p($k_line);
	my @dets = split(/£££/, $k_line);
	my $mapn = $dets[0]; chomp $mapn;
	my $pthw = $dets[1];chomp $pthw;
	my $Rnum = $dets[2]; chomp $Rnum; $Rnum =~ s/rn://;
	if ($kr_numb eq $Rnum){push(@knames, $pthw);}
	}
return @knames;
close KGRR;
}



sub get_keggd{
my ($kr_numb2)= @_;
chomp $kr_numb2;
my @kd_dets;
unless(open(KGRR2, "/var/www/html/kegg_mapno_paths_reactions.txt")) {print "Could not open keggmapinfo file to check\n";}
	
	while (my $k_line2 = <KGRR2>){
	#print $cgdd->p($k_line);
	my @dets = split(/£££/, $k_line2);
	my $mapn2 = $dets[0]; chomp $mapn2;
	my $pthw2 = $dets[1]; chomp $pthw2;
	my $Rnum2 = $dets[2]; $Rnum2 =~ s/rn://; chomp $Rnum2;
	#print $cgdd->p("Here so far:$kr_numb2  and $Rnum2");
	if ($kr_numb2 eq $Rnum2){push(@kd_dets, "$mapn2\t$pthw2");}
	}
return @kd_dets;
close KGRR2;
}


sub get_linkid{
my ($umk, $id, $nm) = @_;
my $in;my $linkid;my @l_id;
	$sth6->execute($nm, $umk, $id);
	while (my $in = $sth6->fetchrow_arrayref()){
			$linkid = $in->[0]; 
			push(@l_id, $linkid); 
			}
return $l_id[0];
}

sub get_microbes{
my ($umk, $id, $pn) = @_;
	my $init; my $mics;my @micr;
	$sth4->execute($pn, $umk, $id);
	while (my $init = $sth4->fetchrow_arrayref()){
			$mics = $init->[0]; 
			push(@micr, $mics); #still needs formatting into table data fields
			}
#return @micr;
my $microbes = join ("\n", @micr);
}

sub get_desc{
my ($umk, $id, $nm) = @_;
	my $des; my $dd;my @dess;
	$sth5->execute($nm, $umk, $id);
	while (my $ds = $sth5->fetchrow_arrayref()){
		$des = $ds->[0];
		push(@dess, $des);
		}
return $dess[0];
}


sub get_pname{
	my (@name_old) = @_;
	my @name_new; my $exists;
	my $names; my @reps;
	my $numb = scalar@name_old;
	if ($numb == 1){$names = $name_old[0];push(@name_new, $name_old[0]);}
	else{
		push(@name_new, $name_old[0]);
		for(my $m =1; $m < @name_old; $m++){
			$exists=0;
			for(my $n = 0; $n < @name_new; $n++){
				if($name_old[$m] eq $name_new[$n]){
					$exists = 1;
					last;
				}
			}if ($exists == 0){push(@name_new, $name_old[$m]);}
		}
	
	
	}

return @name_new;
}


sub brk_dets{
	my ($dets) = @_; 
	my $u; my $e; my $r;my $u1; my $e1; my $r1;
	
	my @try = split(/£££/, $dets);
	$u = $try[0]; if($u){$u1 = $u;}else{$u1 = "None Reported";}
	$e = $try[1]; if($e){$e1 = $e;}else{$e1 = "None Reported";}
	$r = $try[2]; if($r){$r1 = $r;}else{$r1 = "None Reported";}
	
	return ($u1, $e1, $r1);
}


sub getimagetag{
	my ($u) = @_;
	my $imt;my $court;

	if ($u =~ m/^r\d+/){ $imt = 'http://umbbd.ethz.ch/core/graphics/'.$u.'.gif'; $court = 'UMBBD'; }
		elsif($u =~ m/^R\d+/){$imt = 'http://www.genome.jp/Fig/reaction/'.$u.'.gif'; $court = 'KEGG'}
			
		
return ($imt, $court);

}

sub get_go{
	my ($uk) = @_;
	chomp;
#	print $cgdd->p("UMK in the subroutine = $uk");
	my $go_t; my $go_n;
	if ($uk =~ m/^r\d+/){ 
		#print $cgdd->p("UMK in the subroutine loop1 = $uk");
		
		$sth->execute($uk);
		
		while (my $stuff = $sth->fetchrow_arrayref()){
			$go_t = $stuff->[0]; #print $cgdd->p("GO term while in loop:". $go_t);
			$go_n = $stuff->[1]; #print $cgdd->p("GO term while in loop:". $go_n);
		}
	}elsif($uk =~ m/^R\d+/){
		#print $cgdd->p("UMK in the subroutine loop2 = $uk");
		
		$sth2->execute($uk);

		while (my $stuff2 = $sth2->fetchrow_arrayref()){
		$go_t = $stuff2->[0]; #print $cgdd->p("GO term while in loop:". $go_t);
		$go_n = $stuff2->[1]; #print $cgdd->p("GO term while in loop:". $go_n);
		}
	}
		
	
return ($go_t, $go_n);
}


