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

# TODO: this is not correct, the Internal error should be raised all the way up, not as the
# text field...
sub _text_escape {
	my ( $text ) = @_;

	return "" if not $text;
	my $markup = CPAN::Forum::Markup->new();
	my $html   = $markup->posting_process($text);
	if ( not defined $html ) {
		#$self->log->warning("Error displaying already accepted text: '$text'");
		return "Internal Error";
	}
	return $html;

	#$text =~ s{<}{&lt;}g;
	#$text =~ s{\b(http://.*?)(\s|$)}{<a href="$1">$1</a>$2}g; # urls
	#$text =~ s{mailto:(.*?)(\s|$)}{<a href="mailto:$1">$1</a>$2}g; # e-mail addresses
	#return $text;
}

sub format_post {
	my ( $post ) = @_;
	my %post = (
		postername => $post->{username},
		date       => $post->{date},
		parentid   => $post->{parent},
		responses  => $post->{responses},
		text       => _text_escape( $post->{text} ),
		id         => $post->{id},
		subject    => _subject_escape( $post->{subject} ),
	);

	return \%post;
}



1;
