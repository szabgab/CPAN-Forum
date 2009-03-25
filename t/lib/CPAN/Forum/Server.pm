package t::lib::CPAN::Forum::Server;

use strict;
use warnings;
use base qw(HTTP::Server::Simple::CGI);
use HTTP::Server::Simple::Static;

use CPAN::Forum;

our $VERSION = '0.01';

sub handle_request {
	my ($self, $cgi) = @_;

	print "HTTP/1.0 200 OK\r\n";
	my $path = $cgi->path_info;
	if ($path =~  m{^/img/} or $path eq '/style.css') {
		return $self->serve_static( $cgi, "$ENV{CPANFORUM_ROOT}/www" );
	}
	#warn $path;

	my $app = CPAN::Forum->new(
		TMPL_PATH => "$ENV{CPANFORUM_ROOT}/templates",
		PARAMS => {
			ROOT       => $ENV{CPANFORUM_ROOT},
			DB_CONNECT => "dbi:SQLite:$ENV{CPANFORUM_ROOT}/db/forum.db",
			#REQUEST    => $ENV{PATH_INFO},
		},
	);
    $app->run;
	return;
}

1;

