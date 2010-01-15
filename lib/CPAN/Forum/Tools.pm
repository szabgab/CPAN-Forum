package CPAN::Forum::Tools;
use strict;
use warnings;
use 5.008;

use Mail::Sendmail qw(sendmail);


sub _sendmail {
	my ( $users, $mail, $to ) = @_;

	foreach my $user (@$users) {
		#$self->log->debug(Data::Dumper->Dump([$mail], ['mail']));
		my $email = $user->{email};
		$mail->{To} = $email;
		#$self->log->debug("Sending to $email id was found");
		next if $to->{$email}++; #TODO: stop using hardcoded reference to position!!!!!
		#$self->log->debug("Sending to $email first time sending");
		_my_sendmail(%$mail);
		#$self->log->debug("Sent to $email");
	}
}

sub _my_sendmail {
	#my $self = shift;
	my ( %args ) = @_;

	#$self->log->debug(Data::Dumper->Dump([\%args], ['_my_sendmail']));
	#$self->log->debug("_my_sendmail to '$args{To}'");

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
