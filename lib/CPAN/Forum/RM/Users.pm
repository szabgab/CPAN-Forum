package CPAN::Forum::RM::Users;
use strict;
use warnings;

our $VERSION = '0.16';

use CPAN::Forum::DB::Users ();

=head2 users

List the posts of a particular user.

=cut

sub users {
	my $self = shift;

	my $q = $self->query;

	my $username = "";
	$username = ${ $self->query->param("path_parameters") }[0];

	if ( not $username ) {
		return $self->internal_error("No username");
	}

	my $t = $self->load_tmpl(
		"users.tmpl",
		loop_context_vars => 1,
		global_vars       => 1,
	);

	$t->param( hide_username => 1 );

	my $user = CPAN::Forum::DB::Users->info_by( username => $username );

	if ( not $user ) {
		return $self->internal_error("Non existing user was accessed");
	}


	my $fullname = $user->{fullname};

	#$fullname = $username if not $fullname;

	$t->param( this_username => $username );
	$t->param( this_fullname => $fullname );
	$t->param( title         => "Information about $username" );

	my $page = $q->param('page') || 1;
	my $params = $self->_search_results( { where => { uid => $user->{id} }, page => $page } );
	if ($params) {
		$t->param(%$params);
	}

	$t->output;
}

1;

