#!/usr/bin/perl

use strict;
use warnings;
use lib "lib";
use CPAN::Forum::DBI;
use Parse::CPAN::Packages;
use LWP::Simple;
use FindBin qw ($Bin);


my $dir = "$Bin/../db";
my $dbfile = "$dir/forum.db";
CPAN::Forum::DBI->myinit($dbfile);

use CPAN::Forum::Groups;

my $source = shift @ARGV;
print "This operation can take a couple of minutes\n";



if (not $source) {
	my $file = "02packages.details.txt";
	$source = "$dir/$file";

	unlink $source if -e $source;
	# must have downloaded and un-gzip-ed
	# ~/mirror/cpan/modules/02packages.details.txt.gz 
	print "Fecthing  $file from CPAN\n";
	getstore("http://www.cpan.org/modules/02packages.details.txt.gz", "$source.gz");
	print "Unzipping $file\n";
	system("gunzip $source.gz");
}

print "Processing $source file, adding distros to database, will take a few minutes\n";
print "Go get a beer\n";
my $p = Parse::CPAN::Packages->new($source);
my @distributions = $p->distributions;


#my @distributions = ("WWW::Mechanzie", "CGI::Upload", "CGI", "Class::DBI", "CGI::Application", "HTML::Template");  
#my $global = CPAN::Forum::Groups->create({
#	name => "Global",
#	gtype => $CPAN::Forum::DBI::group_types{Global},
#	});

foreach my $d (@distributions) {

	# skip scripts
	next if not $d->prefix or $d->prefix =~ m{^\w/\w\w/\w+/scripts/};	

	
	my $name = $d->dist;
	if (not $name) {
		#warn "No name: " . $d->prefix . "\n";
		next;
	}
	#$name =~ s/-/::/g;
	
	# skip Acme ?
	
	# skip names that start with lower case
	next if $name =~ /^[a-z]/;
	
	# skip existing names
	#next if CPAN::Forum::Groups->search(name => $name);
	eval {
		my $dist = CPAN::Forum::Groups->create({
			name => $name,
			gtype => $CPAN::Forum::DBI::group_types{Distribution}, 
		});
	};
}

