#!/usr/bin/perl
use strict;
use warnings;

use Cwd            qw(abs_path cwd);
use File::Basename qw(dirname);
use Text::CSV_XS;
use FindBin qw ($Bin);

my $dir;
BEGIN {
	$dir = dirname(dirname(abs_path($0)));
	
}
use lib "$dir/lib";

use CPAN::Forum::DBI;
use CPAN::Forum::DB::Groups;


my $csv    = Text::CSV_XS->new();
my $file   = "$dir/cpan_ratings.csv";
my $cnt    = 1;

CPAN::Forum::DBI->myinit();


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



