package CGI::Application::Test;
use strict;
use warnings;

use base 'Exporter';
use Test::Builder;
use Test::More;
use CGI;

our @EXPORT = qw(&cgiapp &extract_cookie);

my $T = Test::Builder->new;
$ENV{CGI_APP_RETURN_ONLY} = 1; # to eliminate screen output
$ENV{HTTP_HOST} = "test-host";

# CGI::Application::Test->new({root => ROOT, cookie => COOKIE_NAME});
sub new {
	my $class = shift;
	my $self = shift;
	bless $self, $class;
}


=head2 cgiapp

$o->cgiapp(PATH_INFO, HTTP_COOKIE, CGI_PARAMS);

CGI_PARAMS is a hash reference such as {a => 23, b => 19}

=cut
sub cgiapp {
	my $self = shift;
	
	local $ENV{PATH_INFO}   = shift;
	my $cookie = shift;
	my $params = shift;
	local $ENV{HTTP_COOKIE} = "$self->{cookie}=$cookie" if defined $cookie; 
	
	my $q = CGI->new($params);
	my $webapp = CPAN::Forum->new(
			TMPL_PATH => "$self->{root}/templates",
		    QUERY => $q,
			PARAMS => {
				ROOT => $self->{root},
			},
	    );
	return $webapp->run();
}

sub extract_cookie {
	my ($self, $result) = @_;
	if ($result =~ /^Set-Cookie: $self->{cookie}=([^;]*);/m) {
		return $1;
	}
}

=pod
sub cookie_set {
	my ($result, $cookie) = @_;
	$T->like($result, qr{^Set-Cookie: $COOKIE=$cookie; domain=$ENV{HTTP_HOST}; path=/}m, 'cookie set');
}


sub setup_sessions {
	my $n = shift;
	my @sids;
	foreach my $i (1 .. $n) {
		my $s = PTI::DB::Session->create;
		push @sids, $s->sid;
	}
	return @sids;
}

=cut

1;


