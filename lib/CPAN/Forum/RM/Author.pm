package CPAN::Forum::RM::Author;
use strict;
use warnings;

use CPAN::Forum::DB::Authors ();
use CPAN::Forum::DB::Groups ();

=head2 author

List posts to dists grouped by author of the dists (PAUSEID)

/author/XYZ

=cut

sub author {
	my ($self) = @_;
	my $q = $self->query;

	my $pauseid = ${ $self->query->param("path_parameters") }[0] || '';
	$self->log->debug("show posts to modules of PAUSEID: '$pauseid'");

	my $t = $self->load_tmpl(
		"authors.tmpl",
		loop_context_vars => 1,
		global_vars       => 1,
	);

	$t->param( pauseid => $pauseid );
	$t->param( title   => "CPAN Forum - $pauseid" );

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
	$self->log->debug("Group IDs: @$group_ids");
	my $page = $q->param('page') || 1;
	if (@$group_ids) {
		$self->_search_results( $t, { where => { gid => $group_ids }, page => $page } );
	}

	#$self->_subscriptions($t, $gr);
	$t->output;
}

1;

