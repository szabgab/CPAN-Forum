package t::lib::CPAN::Forum::Server;

use strict;
use warnings;

use base qw(HTTP::Server::Simple::CGI);
use HTTP::Server::Simple::Static;
use File::Basename qw(dirname);

my $root;
BEGIN {
	$root = dirname(dirname(dirname(dirname(__FILE__))));
}

use CPAN::Forum;

our $VERSION = '0.01';

sub handle_request {
	my ($self, $cgi) = @_;

	print "HTTP/1.0 200 OK\r\n";
	my $path = $cgi->path_info;
	if ($path =~  m{^/img/} or $path eq '/style.css') {
		return $self->serve_static( $cgi, "$root/www" );
	}
	#warn $path;

	my $app = CPAN::Forum->new(
		TMPL_PATH => "$root/templates",
		PARAMS => {
			ROOT       => $root,
			DB_CONNECT => "dbi:SQLite:$ENV{CPAN_FORUM_DB_FILE}",
			#REQUEST    => $ENV{PATH_INFO},
		},
	);
    $app->run;
	return;
}

1;

