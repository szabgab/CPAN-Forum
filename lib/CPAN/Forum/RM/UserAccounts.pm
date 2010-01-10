package CPAN::Forum::RM::UserAccounts;

use strict;
use warnings;
use 5.008;

use Digest::SHA qw(sha1_base64);

sub selfconfig {
	my ( $self, $errs ) = @_;
	my $t = $self->load_tmpl("change_password.tmpl");
	my $user = CPAN::Forum::DB::Users->info_by( id => $self->session->param('uid') ); # SQL
	$t->param( fname => $user->{fname} );
	$t->param( lname => $user->{lname} );

	$t->param($errs) if $errs;
	$t->output;
}

sub change_info {
	my ($self) = @_;
	my $q = $self->query;

	if ( $q->param('fname') !~ /^[a-zA-Z]*$/ ) {
		return $self->selfconfig( { "bad_fname" => 1 } );
	}
	if ( $q->param('lname') !~ /^[a-zA-Z]*$/ ) {
		return $self->selfconfig( { "bad_lname" => 1 } );
	}

	CPAN::Forum::DB::Users->update(
		$self->session->param('uid'), # SQL
		fname => $q->param('fname'),
		lname => $q->param('lname'),
	);

	return $self->selfconfig( { done => 1 } );
}


sub change_password {
	my ($self) = @_;
	my $q = $self->query;

	if ( not $q->param('password') or not $q->param('pw') or ( $q->param('password') ne $q->param('pw') ) ) {
		return $self->selfconfig( { bad_pw_pair => 1 } );
	}

	CPAN::Forum::DB::Users->update(
		$self->session->param('uid'), # SQL
		sha1 => sha1_base64( $q->param('password') ),
	);

	return $self->selfconfig( { done => 1 } );

}



1;

