#!/usr/bin/perl

use strict;
use warnings;
use lib "lib";
use Parse::CPAN::Packages;
use LWP::Simple;
use FindBin qw ($Bin);
use Text::CSV_XS;
use Mail::Sendmail qw(sendmail);

use CPAN::Forum::DBI;
use CPAN::Forum::Groups;




my $dir          = "$Bin/../db";
my $dbfile       = "$dir/forum.db";
my $version_file = "$dir/cpan_versions.txt";

my $csv    = Text::CSV_XS->new();

CPAN::Forum::DBI->myinit($dbfile);



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


my %versions;
open my $in, "<", $version_file or die "Could not open '$version_file' for reading $!\n";
my $cnt = 0;
while (my $line = <$in>) {
	$cnt++;
	if (not $csv->parse($line)) {
		warn "ERROR in line $cnt " . $csv->error_input();
		next;
	}
	my ($name, $version) = $csv->fields();
	$versions{$name} = $version;
}

my $version_message = "";
my $new_message = "";
foreach my $d (@distributions) {

	# skip scripts
	next if not $d->prefix or $d->prefix =~ m{^\w/\w\w/\w+/scripts/};	

	
	my $name = $d->dist;
	if (not $name) {
		#warn "No name: " . $d->prefix . "\n";
		next;
	}
	
	# skip names that start with lower case
	next if $name =~ /^[a-z]/;
	
	my ($g) = CPAN::Forum::Groups->search(name => $name);
	my $version = $d->version();

	if ($g) {
		if ($versions{$name} ne $version) {
			# send e-mail to whoever asked for it.
			$version_message .= "The version of $name has changed from $versions{$name} to $version\n";
		}
	} else {
		$new_message .= "$name      $version\n";
	}
	$versions{$name} = $version;

	next if $g;
	eval {
		my $dist = CPAN::Forum::Groups->create({
			name => $name,
			gtype => $CPAN::Forum::DBI::group_types{Distribution}, 
		});
	};
	if ($@) {
		warn "$name\n";
		warn $@;
	}
}

open my $out, ">", $version_file or die "Could not open '$version_file' for writing $!\n";
foreach my $name (sort keys %versions) {
	print $out qq("$name","$versions{$name}"\n);
}

my %mail = (
	To       => 'gabor@pti.co.il',
	From     => 'cpanforum@cpanforum.com',
	Subject  => 'CPAN Version Update',
	Message  => $version_message,
);
sendmail(%mail);

%mail = (
	To       => 'gabor@pti.co.il',
	From     => 'cpanforum@cpanforum.com',
	Subject  => 'New CPAN Distros',
	Message  => $new_message,
);
sendmail(%mail);



