package CPAN::Forum::RM::Author;
use strict;
use warnings;

our $VERSION = '0.17';

use CPAN::Forum::DB::Authors ();
use CPAN::Forum::DB::Groups ();

=head2 author

List posts to dists grouped by author of the dists (PAUSEID)

/author/XYZ

=cut

sub author {
	my ($self) = @_;
	my $q = $self->query;

	my $pauseid = ${ $self->param("path_parameters") }[0] || '';

	my %params = (
		pauseid => $pauseid,
	);

	my $author = CPAN::Forum::DB::Authors->get_author_by_pauseid($pauseid);
	if ( not $author ) {
		$self->log->warning("Invalid pauseid '$pauseid'");
		return $self->internal_error(
			"",
			"no_such_pauseid",
		);
	}

	# TODO: simplify query!
	my $group_ids = CPAN::Forum::DB::Groups->list_ids_by( pauseid => $author->{id} );
	my $page = $q->param('page') || 1;
	if (@$group_ids) {
		my $results = $self->_search_results( { where => { gid => $group_ids }, page => $page } );
		if ($results) {
			%params = (%params, %$results);
		}
	}

	#my $m = $self->_subscriptions($gr);
	return $self->tt_process('pages/authors.tt', \%params);
}

1;

