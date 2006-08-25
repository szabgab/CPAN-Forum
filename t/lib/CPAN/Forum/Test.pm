package CPAN::Forum::Test;

use File::Copy qw(copy);

require Exporter;
use vars qw(@ISA @EXPORT);
@ISA    = qw(Exporter);

@EXPORT = qw(@users);

my $ROOT = "blib";  

our @users = (
    {
        username => 'abcder',
        email    => 'qqrq@banana.com',
    },
);

sub setup_database {
    chdir "blib";
    copy "../t/CONFIG", ".";
    mkdir "schema";
    copy "../schema/schema.sql", "schema";

    system "$^X ../bin/setup.pl --config CONFIG --dir db";
    system "$^X ../bin/populate.pl --source ../t/02packages.details.txt --dir db";

    chdir "..";
}

sub get_mech {
    use Test::WWW::Mechanize::CGI;
    my $w = Test::WWW::Mechanize::CGI->new;
    mkdir "$ROOT/db";
    $w->cgi(sub {
        require CPAN::Forum;
        my $webapp = CPAN::Forum->new(
                TMPL_PATH => "templates",
                PARAMS => {
                    ROOT       => $ROOT,
                    DB_CONNECT => "dbi:SQLite:$ROOT/db/forum.db"
                },
            );
        $webapp->run();
        }); 
    return $w;
};

sub get_url {
    return "http://cpanforum.local";
}


1;

