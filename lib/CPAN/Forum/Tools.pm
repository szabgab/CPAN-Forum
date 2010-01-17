package CPAN::Forum::Tools;
use strict;
use warnings;
use 5.008;

our $VERSION = '0.17';

use Mail::Sendmail qw(sendmail);

sub _sendmail {
	my ( $users, $mail, $to ) = @_;

	foreach my $user (@$users) {
		my $email = $user->{email};
		$mail->{To} = $email;
		next if $to->{$email}++; #TODO: stop using hardcoded reference to position!!!!!
		_my_sendmail(%$mail);
	}
}

sub _my_sendmail {
	#my $self = shift;
	my ( %args ) = @_;

	return if $ENV{CPAN_FORUM_NO_MAIL};

	# for testing
	#return if $self->config("disable_email_notification");

	if ( defined &_test_my_sendmail ) {
		_test_my_sendmail(@_);
		return;
	} else {
		return sendmail(%args);
	}
}

sub _subject_escape {
	my ($subject) = @_;
	return CGI::escapeHTML($subject);
}


1;
