package CPAN::Forum::RM::Dist;
use strict;
use warnings;

our $VERSION = '0.17';

use CPAN::Forum::DB::Groups;
use CPAN::Forum::DB::Tags;

=head2 dist

List last few posts belonging to this group, provides a link to post a new 
message within this group

/dist/XYZ

=cut

sub dist {
	my ($self) = @_;
	my $q = $self->query;

	my $group_name = ${ $self->param("path_parameters") }[0] || '';
	if ( $group_name =~ /^([\w-]+)$/ ) {
		$group_name = $1;
	} else {
		return $self->internal_error(
			"Probably bad regex when checking group name for '$group_name'",
		);
	}
	$self->log->debug("show dist: '$group_name'");

	my $t = $self->load_tmpl(
		"groups.tmpl",
		loop_context_vars => 1,
		global_vars       => 1,
	);
	$t->param( hide_group => 1 );

	$t->param( group => $group_name );
	$t->param( title => "CPAN Forum - $group_name" );

	my $gr = CPAN::Forum::DB::Groups->info_by( name => $group_name );
	if ( not $gr ) {
		$self->log->warning("Invalid group '$group_name'");
		return $self->internal_error(
			"",
			"no_such_group",
		);
	}
	my $gid = $gr->{id};
	if ( $gid =~ /^(\d+)$/ ) {
		$gid = $1;
	} else {
		return $self->internal_error(
			"Invalid gid received '$gid'",
		);
	}

	$self->set_ratings( $t, $gr );
	my $page = $q->param('page') || 1;
	my $params = $self->_search_results( { where => { gid => $gid }, page => $page } );
	if ($params) {
		$t->param(%$params);
	}
	$self->_subscriptions( $t, $gr );

	# TODO: is is not clear to me how can here anything be undef, but I got
	# several exceptions on eith $gr or $gr->pauseid being undef:
	if ( $gr and $gr->{pauseid_name} ) {
		$t->param( pauseid_name => $gr->{pauseid_name} );
	}

	my $frequent_tags = CPAN::Forum::DB::Tags->get_tags_of_module($gid);
	$t->param( frequent_tags => $frequent_tags );


	my $uid = $self->session->param('uid');
	if ($uid) {
		my $mytags = CPAN::Forum::DB::Tags->get_tags_of( $gid, $uid );
		$t->param( mytags    => $mytags );
		$t->param( show_tags => 1 );
	}
	$t->param( group_id => $gid );

	return $t->output;
}

sub set_ratings {
	my ( $self, $t, $gr ) = @_;

	my ( $rating, $review_count ) = ($gr->{rating}, $gr->{review_count});
	if ( not $rating ) {
		$rating       = "0.0";
		$review_count = 0;
	}
	if ($rating) {
		my $roundrating = sprintf "%1.1f", int( $rating * 2 ) / 2;
		$t->param( rating       => $rating );
		$t->param( roundrating  => $roundrating );
		$t->param( review_count => $review_count );
	}
}


1;

