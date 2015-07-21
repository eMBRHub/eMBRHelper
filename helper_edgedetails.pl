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
my $cgdd = new CGI;
my $edgedets = $cgdd->param('rxndets');
my $from =$cgdd->param('from');
my $to = $cgdd->param('to');
my $rte = $cgdd->param('route');
my $stp = $cgdd->param('rxnstep');
my $comp = $cgdd->param('comp');

#display
print	$cgdd->header;
print	$cgdd->start_html("eMBRHelper decision support - Path details: ".$from."--to--".$to."!");
print   $cgdd->img({-src=>'http://psbtb02.nottingham.ac.uk/logo.jpg'});
#print   $cgi->br();
print	$cgdd->h1("Breakdown of Path Details:");
print   $cgdd->h3("Compound: ".$comp."; ".$rte."; Step ".$stp.".");
print   $cgdd->h3($from. "  ----->  ".$to);
print   $cgdd->hr();
#print	$cgh->p("The table below shows possisble degradation routes for ".$cgh->b($contt)."!");
print  $cgdd->p("Compound A:\t".$from);
print  $cgdd->p("Compound B:\t".$to);
print  $cgdd->p("Details: \t".$edgedets);
#print  $cgd->p("Contents:\t".$contents);




#clean up
#$sth->finish;
$dbh->disconnect;
print $cgdd->end_html;

exit;


