package CPAN::Forum::RM::Admin;
use strict;
use warnings;

our $VERSION = '0.20';

use CPAN::Forum::DB::Users ();
use CPAN::Forum::DB::Configure ();
use CPAN::Forum::DB::Posts ();

sub admin_edit_user_process {
	my ($self) = @_;
	if ( not $self->session->param("admin") ) {
		return $self->internal_error( "", "restricted_area" );
	}
	my $q     = $self->query;
	my $email = $q->param('email');
	my $uid   = $q->param('uid');  # TODO error checking here !

	my $person = CPAN::Forum::DB::Users->info_by( id => $uid );
	if ( not $person ) {
		return $self->internal_error( "", "no_such_user" );
	}
	eval {
		my $person = CPAN::Forum::DB::Users->update( $uid, email => lc $email );
	};
	if ( $@ =~ /column email is not unique/ ) {
		return $self->notes("duplicate_email");
	}

	$self->admin_edit_user( $person->{username}, ['done'] );
}

sub admin_edit_user {
	my ( $self, $username, $errors ) = @_;
	if ( not $self->session->param("admin") ) {
		return $self->internal_error( "", "restricted_area" );
	}
	my $q = $self->query;
	if ( not $username ) {
		$username = ${ $self->param("path_parameters") }[0] || '';
	}

	my $person = CPAN::Forum::DB::Users->info_by( username => $username );
	if ( not $person ) {
		return $self->internal_error( "", "no_such_user" );
	}

	my %params = (
		this_username => $username,
		email         => $person->{email},
		uid           => $person->{id},
	);

	if ( $errors and ref($errors) eq "ARRAY" ) {
		$params{$_} = 1 foreach @$errors;
	}

	return $self->tt_process('pages/admin_edit_user.tt', \%params);
}

sub admin_process {
	my ($self) = @_;
	if ( not $self->session->param("admin") ) {
		return $self->internal_error( "", "restricted_area" );
	}
	my $q = $self->query;

	# fields that can have only one value
	foreach my $field (
		qw(rss_size per_page from flood_control_time_limit
		disable_email_notification)
		)
	{
		CPAN::Forum::DB::Configure->set_field_value( $field, $q->param($field) );
	}

	$self->status( $q->param('status') );


	my %params = ( updated => 1 );
	return $self->tt_process('pages/admin.tt', \%params);
}


sub admin {
	my ($self) = @_;
	if ( not $self->session->param("admin") ) {
		return $self->internal_error( "", "restricted_area" );
	}

	my $data = CPAN::Forum::DB::Configure->get_all_pairs;

	my %params = (
		"status_" . $self->status() => 1, 
		%$data,
	);
	return $self->tt_process('pages/admin.tt', \%params);
}

# Temporary run-mode to delete posts of specific users
sub admin_del_posts {
	my ($self) = @_;
	if ( not $self->session->param("admin") ) {
		return $self->internal_error( "", "restricted_area" );
	}
	my $q = $self->query;

	CPAN::Forum::DB::Posts::delete_posts_of_users();

	my %params = ();
	return $self->tt_process('pages/admin.tt', \%params);
}


1;

