package CPAN::Forum::TestApp;
use strict;
use warnings;

use base 'CGI::Application::Test';
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
	my $webapp = $self->{class}->new(
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


