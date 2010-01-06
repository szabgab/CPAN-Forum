package t::lib::CPAN::Forum::Test;
use strict;
use warnings;

use Cwd            qw(abs_path cwd);
use File::Basename qw(dirname);
use File::Copy     qw(copy);
use File::Path     qw(mkpath);
use File::Temp     qw(tempdir);


my $ROOT = dirname(dirname(dirname(dirname(dirname(abs_path(__FILE__))))));

our @users = (
    {
        username => 'abcder',
        email    => 't@cpanforum.com',
    },
);

sub setup_database {
    $ENV{CPAN_FORUM_DB}   = $ENV{CPAN_FORUM_TEST_DB};
    $ENV{CPAN_FORUM_USER} = $ENV{CPAN_FORUM_TEST_USER};

    # TODO capture STDERR and show if there was an error
    my $out = qx{$^X bin/setup.pl    --email 'test\@perl.org.il' --username testadmin --password pw_of_testadmin --from 'testforum\@perl.org.il' --dbname $ENV{CPAN_FORUM_DB} --dbuser $ENV{CPAN_FORUM_USER} 2>&1};
    if ($out =~ /ERROR/) {
        die $out;
    }
    system "$^X bin/populate.pl --source t/02packages.details.txt ";

    return;
}

sub init_db {
    require CPAN::Forum::DBI;
    $ENV{CPAN_FORUM_DB}   = $ENV{CPAN_FORUM_TEST_DB};
    $ENV{CPAN_FORUM_USER} = $ENV{CPAN_FORUM_TEST_USER};

    CPAN::Forum::DBI->myinit();
}

sub register_user {
    my ($id) = @_;

    init_db();
    require CPAN::Forum::DB::Users;
    my $user = CPAN::Forum::DB::Users->add_user($users[$id]);
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
        push @users, CPAN::Forum::DB::Users->add_user(\%user);
    }
    return @users;
}

sub get_mech {
    # TODO Enable using an environment variable?
    #require Test::WWW::Mechanize;
    #Test::WWW::Mechanize->new;
    
    require Test::WWW::Mechanize::CGI;

    # for some reason the environemnt variable is not visible inside the cgi request
    # so we have to pass them this way:
    my $w = Test::WWW::Mechanize::CGI->new;
    $w->env(
        CPAN_FORUM_LOGFILE => $ENV{CPAN_FORUM_LOGFILE},
        CPAN_FORUM_DB      => $ENV{CPAN_FORUM_TEST_DB},
        CPAN_FORUM_USER    => $ENV{CPAN_FORUM_TEST_USER},
    );

    $w->cgi(sub {
        require CPAN::Forum;

        my $webapp = CPAN::Forum->new(
                TMPL_PATH => "templates",
                PARAMS => {
                    ROOT       => $ROOT,
                },
            );
        $webapp->run();
        }); 
    return $w;
};

sub CPAN::Forum::_test_my_sendmail {
    my %mail = @_;
    my @fields = qw(Message From Subject To);
    my %m;
    @m{@fields} = @mail{@fields};
    push @CPAN::Forum::messages, \%m;
    return;
}

1;

