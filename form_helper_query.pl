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
my $ds = "DBI:mysql:eMBR_helper:localhost";
my $user = "root";
my $passwd = "S952pa74lkp";
my $dbh = DBI->connect($ds,$user,$passwd) || die "Cannot connect to database!!";

#create CGI object
my $cgh = new CGI;
my $contt = $cgh->param('contaminant2');
my $type = $cgh->param('outputtype');

#check for null entry
my $error_m = "";
$error_m .="***Please select a contaminant***.<br/>" if ($contt =~ /Select Contaminant/);
if($error_m){
print $cgh->header;
print $cgh->start_html("eMBR decision Support: entry error.");
print $cgh->img({-src=>'http://psbtb02.nottingham.ac.uk/logo.jpg'});
print $cgh->h1('Results for contaminant: ERROR');
print $cgh->hr();
print $cgh->br();
print $cgh->br();
print $error_m;
print $cgh->br();
print $cgh->br();
print "Go << BACK (on your browser), Correct error and RESUBMIT!\n", $cgh->br;
print $cgh->br();
print $cgh->end_html;
}else{
#start the whole thing
print	$cgh->header;
print	$cgh->start_html('eMBRHelper decision support: results for $contt');
print   $cgh->img({-src=>'http://psbtb02.nottingham.ac.uk/logo.jpg'});
#print   $cgi->br();
print	$cgh->h1('Results for contaminant: '.$contt);
print   $cgh->hr();
#print	$cgh->p("The table below shows possisble degradation routes for ".$cgh->b($contt)."!");

#format graph
my $ty; 
if ($type eq "Show all Edges"){$ty = 0;}elsif($type eq "Concentrate Edges"){$ty = 1;}
#run and report query
my %graph;
my $graphh = GraphViz->new(layout=>'dot', directed =>'1', rankdir => '1', overlap =>'false', concentrate => $ty);
my $input = 'UKMBFinalcomp.csv';

sub _pathsFrom2 {
    use enum qw[ CODE GRAPH START PATH SEEN ]; #perl-enum-1.016-1.2.el5.rf.noarch.rpm

    return $_[CODE]->( @{ $_[PATH] }, $_[START] )
        unless exists $_[GRAPH]->{ $_[START] };

    for ( @{ $_[GRAPH]->{ $_[START] } } ) {
        if( exists $_[SEEN]->{ $_[START] . "-$_" } ) {
            return $_[CODE]->( @{ $_[PATH] }, $_[START] );
        }
        else {
            _pathsFrom2(
                @_[ CODE, GRAPH ], $_,
                [ @{ $_[PATH] }, $_[START] ], { %{ $_[SEEN] }, $_[START] . "-$_", undef } );
        }
    }
}

sub pathsFrom2(&@) { _pathsFrom2( @_, [], {} ) }


open(DATA, "$input") || die "Error opening file $input file!!\n\n";
while( <DATA> ) {
    chomp;
    my @fields = split /\t/, $_;
    push @{ $graph{ $fields[1] } }, $fields[ 3 ];
}


my $colorsfile = '/var/www/html/collours.txt';my @colours; my @htmlc;
open (COLORS, "$colorsfile") || die "Error opening colours file $colorsfile!!\n";
while (my $linec = <COLORS>){chomp $linec; @colours = split (/\n/, $linec);
		push(@htmlc, $linec);
}


#execute 
my $start = $contt;
my $node1 = $start;
my $route = 1;my $col = 0;
my @display_res;

$graphh->add_node($node1, fontsize => '14', URL => "http://psbtb02.nottingham.ac.uk/cgi-bin/helper_compdetails.pl?compound=$node1", color => '#00ff00');

pathsFrom2{
    #print STDERR join "-->", @_;print "\n\n";
	my $routno = ("Route ".$route);
	my $count = @_;
	my $steps = $count - 1;
	my $startnode = $_[0];
	my $endnode = $_[$count-1];
	my $further = "YES";
	my $contents = join("-->",@_);
#	my $details2 = get_enzn();
	my $link2 = $cgh->a({href=>"../cgi-bin/helper_details.pl?comp=$start;rout_no=$routno;count=$count;deg_steps=$steps;start=$startnode;end=$endnode;contents=$contents"}, "DETAILS:$routno");
	push(@display_res, $cgh->Tr( $cgh->td([$routno,$startnode,$endnode,$steps,$further,$link2])));
	$route++;
	foreach (@_){
		$graphh->add_node($_, fontsize => '12', URL => "http://psbtb02.nottingham.ac.uk/cgi-bin/helper_compdetails.pl?compound=$_", color => '#00ff00');
		}
	my $details1 = get_enzn($node1, $_[1]);  #get reaction and enzyme info for the first edge
	my $from1 = $node1; my $to1 = $_[1]; my $step = 1;
	$graphh->add_edge($node1=>$_[1], color => $htmlc[$col], URL => "http://psbtb02.nottingham.ac.uk/cgi-bin/helper_edgedetails2.pl?compound=$node1;route=$routno;from=$from1;to=$to1;rxnstep=$step;rxndets=$details1");

	for(my $x = 1; $x <$count-1; $x++){
		#my ($edg_r, $edg_e) = get_enzn($_[$x], $_[$x+1]);
		my $details = get_enzn($_[$x], $_[$x+1]); #get react no and enzyme info
		my $from = $_[$x]; my $to = $_[$x+1];
		my $stepp = $x+1;
		$graphh->add_node($_[$x], fontsize => '12', URL => "http://psbtb02.nottingham.ac.uk/cgi-bin/helper_compdetails.pl?compound=$_[$x]",color => '#00ff00');
		$graphh->add_edge($_[$x]=>$_[$x+1], color => $htmlc[$col], URL => "http://psbtb02.nottingham.ac.uk/cgi-bin/helper_edgedetails2.pl?compound=$startnode;route=$routno;from=$from;to=$to;rxnstep=$stepp;rxndets=$details");
		}
		$col++;
} \%graph, $start;



 my $imageh = $graphh->as_canon;
 my $doth_fh = IO::String->new($imageh);
 my $time = time;
 my $filename = "helper3$time";
 my $outhfile = "/var/www/html/$filename.dot";
 sysopen (OUTFH, $outhfile, O_RDWR| O_CREAT | O_TRUNC, 0755) or die "Can't open $outhfile for writing:$!\n";
 
 while (my $lineh = <$doth_fh>){
		print OUTFH "$lineh";
		}

#finish up
close OUTFH;

##Display##
my $routenos = @display_res;
print	$cgh->p("The table below shows ".$cgh->b($routenos)." possible routes for degradation of ".$cgh->b($contt)."!");

#display graph
print $cgh->a({-href=>'/cgi-bin/webdot.pl/http://psbtb02.nottingham.ac.uk/'.$filename.'.dot.dot.svg', -target=>'newWindow',-onclick=>'window.open(this.href, this.target); return false' }, 'Click Here for Interactive Graphical Display'); print $cgh->i("(OPENS IN NEW WINDOW: Click on nodes for compound information and on edges for reaction information!!)");

my $bt = $ENV{HTTP_USER_AGENT};
if (index($bt, "MSIE") > -1){print $cgh->br();print $cgh->small("AND!! You appear to be using Internet Explorer. Please be adviced that these are SVG images and early versions of Internet Explorer may not support them!");}
#print   $cgh->img({-src=>'/cgi-bin/webdot.pl/http://psbtb02.nottingham.ac.uk/'.$filename.'.dot.dot.svg'}, "Image");
#



#print results
print $cgh->br();
if (!@display_res){print $cgh->p("Sorry! Your Query did not match any information in our current database!!");
}else{

if(($routenos>50)&& $ty eq '0'){
	print $cgh->i("Please note that given the number of possible degradation routes for this compound a graph with 'concentrated' edges may be easier to appreciate");
	print $cgh->p("TABULAR DISPLAY:");
	print $cgh->p("Click on DETAILS for further information");}
else{
	print $cgh->p("TABULAR DISPLAY:");
	print $cgh->p("Click on DETAILS for further information");

}
print $cgh->table({-border=>'1', cellpadding => '1', cellspacing => '1'},
		$cgh->Tr([
			$cgh->th(['Routes', 'Start Compd.','End Compd.','Degradation Steps','Further deg. paths', 'Details: 				CLICK'])
			]),
			@display_res
		);
}

#clean up
#$sth->finish;
$dbh->disconnect;
print $cgh->end_html;
}
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
			$rid = getr_id($a, $b);#using substrate and product to get reaction ID.
			push (@dets, ($rno."£££".$enzyme."£££".$rid)); # react.number and enz from file, react id from db
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

my $substrate = @sub;
my $product = @prd;
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

