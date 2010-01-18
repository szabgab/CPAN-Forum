package CPAN::Forum::RM::Users;
use strict;
use warnings;

our $VERSION = '0.18';

use CPAN::Forum::DB::Users ();

=head2 users

List the posts of a particular user.

=cut

sub users {
	my $self = shift;

	my $q = $self->query;

	my $username = "";
	$username = ${ $self->param("path_parameters") }[0];

	if ( not $username ) {
		return $self->internal_error("No username");
	}

	my $user = CPAN::Forum::DB::Users->info_by( username => $username );

	if ( not $user ) {
		return $self->internal_error("Non existing user was accessed");
	}


	my $fullname = $user->{fullname};

	#$fullname = $username if not $fullname;

	my %params = (
		hide_username => 1,
		this_username => $username,
		this_fullname => $fullname,
		title         => "Information about $username",
	);

	my $page = $q->param('page') || 1;
	my $listing = $self->_search_results( { where => { uid => $user->{id} }, page => $page } );
	if ($listing) {
		%params = (%params, %$listing);
	}

	return $self->tt_process('pages/users.tt', \%params);
}

1;

