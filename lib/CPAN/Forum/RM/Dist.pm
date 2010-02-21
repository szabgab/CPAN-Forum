package CPAN::Forum::RM::Dist;
use strict;
use warnings;

our $VERSION = '0.19';

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

	my %params = (
		hide_group => 1,
		group => $group_name,
		title => "CPAN Forum - $group_name",
	);

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

	my $more_params = $self->set_ratings( $gr );
	%params = (%params, %$more_params);
	my $page = $q->param('page') || 1;
	my $results = $self->_search_results( { where => { gid => $gid }, page => $page } );
	if ($results) {
		%params = (%params, %$results);
	}
	my $mp = $self->_subscriptions( $gr );
	%params = (%params, %$mp);

	# TODO: is is not clear to me how can here anything be undef, but I got
	# several exceptions on eith $gr or $gr->pauseid being undef:
	if ( $gr and $gr->{pauseid_name} ) {
		$params{pauseid_name} = $gr->{pauseid_name};
	}

	my $frequent_tags = CPAN::Forum::DB::Tags->get_tags_of_module($gid);
	$params{frequent_tags} = $frequent_tags;


	my $uid = $self->session->param('uid');
	if ($uid) {
		my $mytags = CPAN::Forum::DB::Tags->get_tags_of( $gid, $uid );
		$params{mytags} = $mytags;
		$params{show_tags} = 1;
	}
	$params{group_id} = $gid;

	return $self->tt_process('pages/dists.tt', \%params);
}

sub set_ratings {
	my ( $self, $gr ) = @_;


	my ( $rating, $review_count ) = ($gr->{rating}, $gr->{review_count});
	if ( not $rating ) {
		$rating       = "0.0";
		$review_count = 0;
	}
	return {} if not $rating; # ????

	my $roundrating = sprintf "%1.1f", int( $rating * 2 ) / 2;
	return {
		rating       => $rating,
		roundrating  => $roundrating,
		review_count => $review_count,
	}
}


1;

