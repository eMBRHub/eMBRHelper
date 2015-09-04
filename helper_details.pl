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
my $cgd = new CGI;
my $comp = $cgd->param('comp');
my $route = $cgd->param('rout_no');
my $num = $cgd->param('count');
my $dsteps = $cgd->param('deg_steps');
my $start = $cgd->param('start');
my $end = $cgd->param('end');
my $contents = $cgd->param('contents');

print	$cgd->header;
print	$cgd->start_html("eMBRHelper decision support: Degradation path for ".$comp.":".$route."!");
print   $cgd->img({-src=>'http://psbtb02.nottingham.ac.uk/logo.jpg'});
#print   $cgi->br();
print	$cgd->h1("Degradation Path for ".$comp.": ".$route);
print   $cgd->hr();
#print	$cgh->p("The table below shows possisble degradation routes for ".$cgh->b($contt)."!");
print  $cgd->p("Start compound:\t".$comp);
print  $cgd->p("End compound:\t".$end);
print  $cgd->p("Degradation steps involved:\t".$dsteps);
#print  $cgd->p("Contents:\t".$contents);


my $input = 'UKMBFinalcomp.csv';

my @fields = split (/-->/, $contents);
my @display; my $space0 = " "; my $space1 = "~------>"; my $space2 = "";
my $complink = $cgd->a({href=>"../cgi-bin/helper_compdetails.pl?compound=$fields[0]"}, "$fields[0]");
push(@display, $cgd->Tr( $cgd->td([$cgd->b($complink.":"), $space0, $space2])));

#my $size = @fields;
#execute and run graphviz
my $graphd = GraphViz->new(layout=>'dot', directed =>'1', rankdir => '0', overlap =>'scale');
	foreach (@fields){
		$graphd->add_node($_, fontsize => '10', URL => "http://psbtb02.nottingham.ac.uk/cgi-bin/helper_compdetails.pl?compound=$_",color => '#00ff00');
		}
	for(my $x = 0; $x <$num-1; $x++){
		my $details = get_enzn($fields[$x], $fields[$x+1]); #get react no and enzyme info
		my $from = $fields[$x]; my $to = $fields[$x+1];my $stp = $x+1;
		$graphd->add_edge($fields[$x]=>$fields[$x+1], URL => "http://psbtb02.nottingham.ac.uk/cgi-bin/helper_edgedetails2.pl?compound=$comp;from=$from;to=$to;route=$route;rxnstep=$stp;rxndets=$details");
		
		my $edgelink = $cgd->a({href=>"../cgi-bin/helper_edgedetails2.pl?compound=$comp;from=$from;to=$to;route=$route;rxnstep=$stp;rxndets=$details"}, "$space1");
		my $complink2 = $cgd->a({href=>"../cgi-bin/helper_compdetails.pl?compound=$fields[$x+1]"}, "$fields[$x+1]");
		push(@display, $cgd->Tr( $cgd->td([$space0, $edgelink, $complink2])));
		}
#prepare graphviz image
 my $imageh = $graphd->as_canon;
 my $doth_fh = IO::String->new($imageh);
 my $time = time;
 my $filename = "helper2$time";
 my $outhfile = "/var/www/html/$filename.dot";
 sysopen (OUTFH, $outhfile, O_RDWR| O_CREAT | O_TRUNC, 0755) or die "Can't open $outhfile for writing:$!\n";
 
 while (my $lineh = <$doth_fh>){
		print OUTFH "$lineh";
		}

#finish up
close OUTFH;


#display graph
print $cgd->a({-href=>'/cgi-bin/webdot.pl/http://psbtb02.nottingham.ac.uk/'.$filename.'.dot.dot.svg', -target=>'newWindow',-onclick=>'window.open(this.href, this.target); return false' }, 'Click Here for Interactive Image'); print $cgd->i("(Opens in new window!)");
#print   $cgd->img({-src=>'/cgi-bin/webdot.pl/http://psbtb02.nottingham.ac.uk/'.$filename.'.dot.dot.svg'});
#


my @display_res = 1;
my $disp_size = scalar@display;
#print results
if (@display==1){print $cgd->p("Sorry! Your Query did not match any information in our current database!!");
}else{
print $cgd->br;
print $cgd->br;
print $cgd->b("Deg. Path:");
print $cgd->small("Click on '~----->' and(or) on 'Compound names' for further information");
print $cgd->br;
print $cgd->br;
print $cgd->table({-border=>'0', cellpadding => '0', cellspacing => '1'},
		$cgd->Tr([
			$cgd->th(['', ''])
			]),
			@display
		);
}





#clean up
#$sth->finish;
#$sth1->finish;
$dbh->disconnect;
print $cgd->end_html;

exit;




####Subroutines####
sub get_enzn{
 	my ($a1, $b1) = @_;
	my $detss;
	my @details = get_dets($a1, $b1);
	my $size = @details;
	if ($size == 1){$detss = $details[0];}
			elsif($size > 1){$detss = join(";", @details);}
return ($detss);
}


sub get_dets{
	my($a, $b) = @_;
	#print "a:$a\n"; print "b:$b\n";
	my @reactinfo; my $rno; my $enzyme; my @dets; my $rid;
	unless (open(MAIN, "UKMBFinalcomp.csv")){print "Could not open main reactions file for read!!\n";}
	
	while (my $line = <MAIN>){
		#print "$line\n";
		@reactinfo = split(/\t/, $line);
		chomp $reactinfo[0]; chomp $reactinfo[1]; chomp $reactinfo[2]; chomp $reactinfo[3]; 
		
		if(($reactinfo[1] eq $a) && ($reactinfo[3] eq $b)){
			#print "matched\n";
			$rno = $reactinfo[0];
			$enzyme = $reactinfo[2];
			$rid = getr_id($a, $b);  #using substrate and product to get reaction ID.
			push (@dets, ($rno."£££".$enzyme."£££".$rid));
			}
	
	}
return @dets;
}


sub getr_id{
	my ($s, $p) = @_;
	my $id;

	my $squery = q(SELECT reaction_iden FROM participates_in WHERE compound_name = ? AND role = 'substrate');
	my $sth = $dbh->prepare($squery);
	$sth->execute($s);

	my $pquery = q(SELECT reaction_iden FROM participates_in WHERE compound_name = ? AND role = 'product');
	my $sth1 = $dbh->prepare($pquery);
	$sth1->execute($p);

my @sub; my @prd; my @reactrecs;
while (my $resultssub = $sth->fetchrow_arrayref()){
	push(@sub, $resultssub->[0]); 
	}

while (my $resultsprd = $sth1->fetchrow_arrayref()){
	push (@prd, $resultsprd->[0]);
	}

my $substrate = scalar@sub;
my $product = scalar@prd;
	for (my $y=0;$y<$substrate;$y++){
		for (my $z=0; $z<$product;$z++){
		if($sub[$y] eq $prd[$z]){
			my $reactid = $sub[$y];
			push(@reactrecs, $reactid);
			}
		}
	}

$id = $reactrecs[0];
return $id;

$sth->finish;
$sth1->finish;
}
