package CPAN::Forum::Markup;
use strict;
use warnings;

use CGI qw(escapeHTML);

sub new {
	my ($class) = @_;
	bless {}, $class;
}


# will someone simplify this code ??
sub posting_process {
	my ($self, $t) = @_;

	my ($text, $rest) = split /<code>/, $t, 2;
	my $ret = $self->text_proc($text);
	if (not $rest) {
		if ($t =~ /<code>/) {
			die "ERR open_code_without_closing\n";
		} else {
			return $ret;
		}
	}

	die "ERR open_code_without_closing\n" if $rest !~ m{</code>};
	my ($code, $more) = split /<\/code>/, $rest, 2;
	$ret .= $self->code_proc($code);
	$ret .= $self->posting_process($more) if $more;
	return $ret;
}


sub text_proc {
	my ($self, $text) = @_;
	die "ERR no_less_sign\n" if $text =~ /</;
	$self->line_width($text);
	$text = escapeHTML $text;
	return qq(<div class="text">$text</div>\n);
}

sub code_proc {
	my ($self, $code) = @_;
	$self->line_width($code);
	#$code =~ s/</&lt;/g;
	$code = escapeHTML $code;
	return qq(<div class="code">$code</div>\n);
}

sub line_width {
	my ($self, $str) = @_;
	my @lines = split /\n/, $str;
	foreach my $line (@lines) {
		die "ERR line_too_long\n" if length $line > 70;
	}
	return 1;
}




1;

