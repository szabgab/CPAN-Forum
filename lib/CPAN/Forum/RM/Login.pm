package CPAN::Forum::RM::Login;
use strict;
use warnings;

our $VERSION = '0.16';

use List::MoreUtils qw(none);
use Digest::MD5 qw(md5_base64);

use CPAN::Forum::Tools ();
use CPAN::Forum::DB::Users ();

=head2 login

Show the login form and possibly some error messages.

=cut

sub login {
	my ( $self, $errs ) = @_;
	my $q = $self->query;

	$self->log->debug( "Sending cookie using sid:  " . $self->session->id() );
	$self->session_cookie();

	my %params;
	%params = %$errs if $errs;
	$params{nickname} = $q->param('nickname'); # TODO associate?
	return $self->tt_process('pages/login.tt', \%params);
}

=head2 login_process

- Processing the information provided by the user, 
- calling for authentication
- setting the session

- redirecting to the page where the user wanted to go before he was diverted to the login page

=cut

sub login_process {
	my $self = shift;
	my $q    = $self->query;

	if ( not $q->param('nickname') or not $q->param('password') ) {
		return $self->login( { no_login_data => 1 } );
	}


	my $user = CPAN::Forum::DB::Users->info_by_credentials( $q->param('nickname'), $q->param('password') );
	if ( not $user ) {
		$self->log->debug("No user found");
		return $self->login( { bad_login => 1 } );
	}
	$self->log->debug( "Username: " . $user->{username} );

	my $session = $self->session;
	$session->param( admin => 0 ); # make sure it is clean

	$session->param( loggedin => 1 );
	$session->param( username => $user->{username} );
	$session->param( uid      => $user->{id} );
	$session->param( fname    => $user->{fname} );
	$session->param( lname    => $user->{lname} );
	$session->param( email    => $user->{email} );
	if ( CPAN::Forum::DB::Users->is_admin( $user->{id} ) ) {
		$session->param( admin => 1 );
	}

	my $request = $session->param("request") || "home";
	$self->log->debug("Request redirection: '$request'");
	my $response;
	eval {
		if ( $request eq 'new_post' )
		{
			my $request_group = $session->param("request_group") || '';
			$self->param( "path_parameters" => [$request_group] );
		}
		$response = $self->$request();
	};
	if ($@) {
		$self->log->error($@);
		die $@; # TODO: send error page?
	}
	$session->param( "request"       => "" );
	$session->param( "request_group" => "" );
	$session->flush();
	$self->log->debug( "Session flushed after login " . $session->param('loggedin') );
	return $response;
}


=head2 logout

Set the session to be logged out and remove personal information from the Session object.

=cut

sub logout {
	my $self = shift;

	my $session  = $self->session;
	my $username = $session->param('username');
	$session->param( loggedin => 0 );
	$session->param( username => '' );
	$session->param( uid      => '' );
	$session->param( fname    => '' );
	$session->param( lname    => '' );
	$session->param( email    => '' );
	$session->param( admin    => '' );
	$session->flush();
	$self->log->debug("logged out '$username'");

	$self->home;
}

=head2 pwreminder

Show form to ask for password reminder e-mail

=cut

sub pwreminder {
	my ( $self, $errs ) = @_;
	my $q = $self->query;

	my $t = $self->load_tmpl(
		"pwreminder.tmpl",
		associate => $q,
	);

	$t->param($errs) if $errs;
	$t->param( $q->param('field') => 1 ) if $q->param('field') and $q->param('field') =~ /^username|email$/;
	return $t->output;
}


=head2 pwreminder_process

Process the request to get a reminder about the password.

=cut

sub pwreminder_process {
	my ($self) = @_;
	my $q      = $self->query;
	my $field  = $q->param('field');
	my @FIELDS = qw(username email);
	if ( not $field or not $q->param('value') or none { $field eq $_ } @FIELDS ) {
		return $self->pwreminder( { "no_data" => 1 } );
	}

	my $user = CPAN::Forum::DB::Users->info_by( $field => $q->param('value') );
	return $self->pwreminder( { "no_data" => 1 } ) if not $user;

	# TODO: put this text in a template
	my $password = $user->{password};
	my $username = $user->{username};
	my $subject  = "CPAN::Forum password reminder";
	my $message  = <<MSG;

Your nickname is $username
Your secret key to CPAN::Forum is: $password
Use it wisely.

http://$ENV{HTTP_HOST}/


MSG

	my $FROM = $self->config("from");
	$self->log->debug("FROM field set to be $FROM");

	my %mail = (
		To      => $user->{email},
		From    => $FROM,
		Subject => $subject,
		Message => $message,
	);
	CPAN::Forum::Tools::_my_sendmail(%mail);

	return $self->pwreminder( { "done" => 1 } );
}

sub reset_password_form {
	my $self = shift;
	my $error = shift;

	my $q = $self->query;
	my %params = (
		code => $q->param('code'),
	);
	if ($error) {
		$params{$error} = 1;
	}
	return $self->tt_process('pages/reset_password_form.tt', \%params);
}
sub reset_password_form_process {
	my $self = shift;
	my $q = $self->query;

	my $pw1 = $q->param('password1');
	my $pw2 = $q->param('password2');
	my $code = $q->param('code');

	if (not $pw1) {
		return $self->reset_password_form('no_password1');
	} elsif (not $pw2) {
		return $self->reset_password_form('no_password2');
	} elsif (not $code) {
		return $self->reset_password_form('no_code');
	} elsif ($pw1 ne $pw2) {
		return $self->reset_password_form('not_matching');
	}

	# get user from code
	# check if the runodes match
	# update password, remove code
	
	return $self->tt_process('pages/reset_password_done.tt');
}

sub reset_password_request {
	my $self = shift;
	my $error = shift;
	my $q = $self->query;

	my %params = (
		username => $q->param('username'),
		email    => $q->param('email'),
	);
	if ($error) {
		$params{$error} = 1;
	}
	return $self->tt_process('pages/reset_password_request.tt', \%params);
}

sub reset_password_request_process {
	my $self = shift;
	my $q = $self->query;


	my $user;
	if ($q->param('email')) {
  		$user = CPAN::Forum::DB::Users->info_by( email => $q->param('email') );
	} elsif ($q->param('username')) {
  		$user = CPAN::Forum::DB::Users->info_by( username => $q->param('username') );
	} else {
		return $self->reset_password_request('no_param');
	}
	if (not $user) {
		return $self->reset_password_request('no_such_user');
	}

	# generate code
	use CPAN::Forum::DB::Users;
	my $code = CPAN::Forum::DB::Users::_generate_pw(20);


	$self->send_password_reset_code($user, $code);
	return $self->tt_process('pages/reset_password_request_processed.tt');
}


=head2 register

Show the registration page and possibly some error messages.

=cut

sub register {
	my ( $self, $errs ) = @_;
	my $q = $self->query;

	my %params;
	%params = %$errs if $errs;
	$params{$_} = $q->param($_) for qw(nickname email fname lname); # TODO associate?
	return $self->tt_process('pages/register.tt', \%params);
}


=head2 register_process

Process the registration form.

=cut

sub register_process {
	my ($self) = @_;
	my $q = $self->query;

	if ( not $q->param('nickname') or not $q->param('email') ) {
		return $self->register( { "no_register_data" => 1 } );
	}

	# TODO arbitrary nickname constraint, allow other nicknames ?
	if ( $q->param('nickname') !~ /^[a-z0-9]{1,25}$/ ) {
		return $self->register( { "bad_nickname" => 1 } );
	}

	# TODO fix the e-mail checking and the error message
	if ( $q->param('email') !~ /^[a-z0-9_+@.-]+$/ ) {
		return $self->register( { "bad_email" => 1 } );
	}

	my $user = eval {
		CPAN::Forum::DB::Users->add_user(
			{
				username => $q->param('nickname'),
				email    => $q->param('email'),
			}
		);
	};
	if ($@) {
		return $self->register( { "nickname_exists" => 1 } );
	}

	$self->send_password($user);
	$self->notify_admin($user);
	return $self->register( { "done" => 1 } );
}

sub send_password_reset_code {
	my ( $self, $user, $code ) = @_;

	# TODO: put this text in a template
	my $subject  = "CPAN::Forum password reset code";
	my $message  = <<MSG;

http://$ENV{HTTP_HOST}/reset_password_form?code=$code

MSG

	my $FROM = $self->config("from");

	my %mail = (
		To      => $user->{email},
		From    => $FROM,
		Subject => $subject,
		Message => $message,
	);
	CPAN::Forum::Tools::_my_sendmail(%mail);
}


sub send_password {
	my ( $self, $user ) = @_;

	# TODO: put this text in a template
	my $password = $user->{password};
	my $subject  = "CPAN::Forum registration";
	my $message  = <<MSG;

Thank you for registering on the CPAN::Forum at
http://$ENV{HTTP_HOST}/

your password is: $password


MSG

	my $FROM = $self->config("from");
	$self->log->debug("FROM field set to be $FROM");

	my %mail = (
		To      => $user->{email},
		From    => $FROM,
		Subject => $subject,
		Message => $message,
	);
	CPAN::Forum::Tools::_my_sendmail(%mail);
}

1;

