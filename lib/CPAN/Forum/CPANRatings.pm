package CPAN::Forum::CPANRatings;
use strict;
use warnings;

our $VERSION = '0.18';

=head1 NAME

CPAN::Forum::CPANRatings - fetch data from CPANRATINGS.perl.org and integrate in our database

=cut

use Moose;
use File::Temp      qw(tempdir);
use LWP::Simple     qw(getstore);
use Text::CSV_XS    ();

use CPAN::Forum::DBI;
use CPAN::Forum::DB::Groups;

#has 'dir';  # should hold the place where we keep the old  


sub run {
	my $self = shift;

	my $csv  = Text::CSV_XS->new();
	my $dir  = tempdir( CLEANUP => 1 );
	my $file = "$dir/cpan_ratings.csv";
	my $cnt  = 1;

	getstore('http://cpanratings.perl.org/csv/all_ratings.csv', $file);
	if (not -e $file) {
		warn "File could not be mirrored\n";
		# TODO some sanity check on the size of the file?
		return;
	}

	CPAN::Forum::DBI->myinit();

	open my $fh, "<", $file or die "Could not open '$file'\n";
	my $line = <$fh>;
	chomp $line;

	die "File format changed\n"
		if $line ne '"distribution","rating","review_count"';

	my @header = ( "distribution", "rating", "review_count" );

	my $groups = CPAN::Forum::DB::Groups->list_groups_with_rating();

	while ( my $line = <$fh> ) {
		$cnt++;
		if ( not $csv->parse($line) ) {
			warn "ERROR in line $cnt " . $csv->error_input();
			next;
		}
		my %field;
		@field{@header} = $csv->fields();
		if ($field{distribution} eq '-0.01') {
			# some bug in the data supplied I guess
			next;
		}
		# TODO check if the supplied data is really numbers in the correct format
		if ($groups->{ $field{distribution} }) {
			print "Processing '$field{distribution} to $field{review_count} $field{rating}\n";
			if (not defined $groups->{ $field{distribution} }{rating}
				or $groups->{ $field{distribution} }{rating} != $field{rating}
				or not defined $groups->{ $field{distribution} }{review_count}
				or $groups->{ $field{distribution} }{review_count} != $field{review_count}) {
					print "    Updating '$field{distribution} to $field{review_count} $field{rating}\n";
					CPAN::Forum::DB::Groups->update_rating(\%field);
			}
		} else {
			print "ERROR: '$field{distribution}' listed on CPANRatings is not in the database\n";
		}
		#<STDIN>;
	}
}




1;

