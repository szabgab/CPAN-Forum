package t::lib::CPAN::Forum::Test;
use strict;
use warnings;

use File::Copy qw(copy);
use File::Temp qw(tempdir);

my $ROOT = tempdir( CLEANUP => 1 );

our @users = (
    {
        username => 'abcder',
        email    => 't@cpanforum.com',
    },
);

sub setup_database {
    copy 't/CONFIG', $ROOT;
    mkdir "$ROOT/schema";
    mkdir "$ROOT/db";
    copy 'schema/schema.sql', "$ROOT/schema";
    copy 't/02packages.details.txt', $ROOT;

    my $dir = Cwd::cwd;
	
    chdir $ROOT;

    system "$^X $dir/bin/setup.pl --config CONFIG --dir db";
    system "$^X $dir/bin/populate.pl --source 02packages.details.txt --dir db";

    chdir $dir;
    
    return $ROOT;
}

sub init_db {
    require CPAN::Forum::DBI;
    CPAN::Forum::DBI->myinit(db_connect());
}

sub db_connect {
    return "dbi:SQLite:$ROOT/db/forum.db";
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
                    DB_CONNECT => db_connect(),
                },
            );
        $webapp->run();
        }); 
    return $w;
};

sub get_url {
    return "http://cpanforum.local";
}

sub register_user {
    my ($id) = @_;

    init_db();
    require CPAN::Forum::DB::Users;
    my $user = CPAN::Forum::DB::Users->create($users[$id]);
    return $user;
}

sub register_users {
    my ($id, $n) = @_;

    init_db();
    require CPAN::Forum::DB::Users;
    my @users;
    foreach my $i (1..$n) {
        my %user;
        $user{$_} = $i . $users[$id]{$_} foreach qw(username email);
        push @users, CPAN::Forum::DB::Users->create(\%user);
    }
    return @users;
}



1;

