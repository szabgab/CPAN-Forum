#!/usr/bin/perl
use strict;
use warnings;


use Text::CSV_XS;

use lib "lib";
use CPAN::Forum::DBI;
use CPAN::Forum::DB::Groups;
use FindBin qw ($Bin);

my $dir = "$Bin/../db";

my $csv    = Text::CSV_XS->new();
my $file   = "$dir/cpan_ratings.csv";
my $cnt    = 1;
my $dbfile = "$dir/forum.db";

CPAN::Forum::DBI->myinit($dbfile);


open my $fh, "<", $file or die "Could not open '$file'\n";
my $line = <$fh>;
chomp $line;

die "File format changed\n" if $line ne '"distribution","rating","review_count"';
my @header = ("distribution","rating","review_count");

#my @groups = CPAN::Forum::DB::Groups->retrieve_all();

while (my $line = <$fh>) {
	$cnt++;
	if (not $csv->parse($line)) {
		warn "ERROR in line $cnt " . $csv->error_input();
		next;
	}
	my %field;
	@field{@header} = $csv->fields();
	my ($g) = CPAN::Forum::DB::Groups->search(name => $field{distribution});
	if ($g) {
		#print "    FOUND\n";
	} else {
		print "$field{distribution}\n";
		#print "    MISSING\n";
	}

	#<STDIN>;
}

sleep 10;



