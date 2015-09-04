#!/usr/bin/perl

use strict;
use warnings;
use CGI qw( :standard );
use CGI::Carp qw( fatalsToBrowser );
use CGI::Pretty;
use DBI;
use lib '/usr/lib/perl5/site_perl/5.8.8/i386-linux-thread-multi/DBD/mysql.pm';
use IO::String;
use File::Copy;
use Fcntl; 
use Data::Dump qw[ pp ]; #perl-Data-Dump.noarch 0:1.08-3.el5
use List::Util qw[ shuffle ];
use Time::HiRes qw[ time ];
use Text::Wrap;
$Text::Wrap::columns = 60;


#connect to the database
my $ds = "DBI:mysql:xxxxx:localhost";#replace xxxx with database name
my $user = "root";
my $passwd = "xxxxxx"; #replace xxxx with appropriate password

my $dbh = DBI->connect($ds,$user,$passwd) || die "Cannot connect to database!!";

#create CGI object
my $cgem = new CGI;

my $enzyme = $cgem->param('EnzymeName');
my $microbe = $cgem->param('Microorganism');
chomp $enzyme; chomp $microbe;

my $sthmq;my @enzmi;

if (($microbe eq "ALL") || ($microbe eq "Microorganisms(ALL)")){
			$sthmq = $dbh->prepare("SELECT * FROM enzyme_in WHERE enzymeName = ?");
			$sthmq->execute($enzyme);}
elsif ($enzyme eq "ALL"){
			$sthmq = $dbh->prepare("SELECT * FROM enzyme_in WHERE microbeName = ?");
			$sthmq->execute($microbe);}
		else{
		$sthmq = $dbh->prepare("SELECT * FROM enzyme_in WHERE enzymeName = ? AND microbeName = ?");
		$sthmq->execute($enzyme, $microbe);}


my $nam; my $micm; my $prt; my $nb; my $ss; my $prtw;my $fasta;my $fprtw;
while (my $emic = $sthmq->fetchrow_arrayref()){
		$nam = $emic->[2];
		$micm = $emic->[3];
		$fasta = $emic->[5]; chomp $fasta;
		$prt = $emic->[6];  $prtw = wrap('', '', $prt); 
		$fprtw = "$fasta\n$prtw";
		$nb = $emic->[4];
		$ss= $emic->[7];
		push(@enzmi, $cgem->Tr($cgem->td([$nam, $micm, $fprtw,$nb,$ss])));
		}

my @enzmi2 = get_pname(@enzmi);
my $arrrsize = @enzmi2;
#new web page
print	$cgem->header;
print	$cgem->start_html('Enzyme-Microbe query result');
print   $cgem->img({-src=>'http://psbtb02.nottingham.ac.uk/logo.jpg'});
print   $cgem->br();
print 	$cgem->h2("MICROBE INFO:");
print 	$cgem->h4("Enzyme: ".$cgem->b($enzyme).". Microorganism(s) where found:");
print   $cgem->hr();
	#$cgem->pre($usequery);

#print $cgem->p("$enzmi2[1]");

#print results

if(!@enzmi2){
	print $cgem->p("SORRY! Your query resulted in NO matches from our current database!");
	}else{
		print $cgem->small("$arrrsize record(s) returned!");
		print $cgem->table(
		{-border => '1', cellpadding => '1', cellspacing => '1'},
		$cgem->Tr([
			$cgem->th({-bgcolor=>"aquamarine", -font size=>"4",},['Enzyme', 'Microbe', 'Protein Sequence', 'No. of bases', 'Source'])
		]),

		@enzmi2
		);
	}

print $cgem->br();
print $cgem->br();

#possible other searches

print $cgem->p('Do you want to do another search?');
print $cgem->p('Click', a({href => '/microbedata.html'}, 'HERE'));

#clean up
$sthmq->finish;
$dbh->disconnect;
print $cgem->end_html;



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
