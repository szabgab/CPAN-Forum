#!/usr/bin/perl

use strict;
use warnings;

use Storable qw(dclone);
use Test::WWW::Mechanize;
use Test::Most;

plan skip_all => 'Need CPAN_FORUM_DB_FILE and CPAN_FORUM_TEST_URL' 
	if not $ENV{CPAN_FORUM_DB_FILE} or not $ENV{CPAN_FORUM_TEST_URL};

my $tests;
plan tests => $tests;

bail_on_fail;

use t::lib::CPAN::Forum::Test;
my @users = @t::lib::CPAN::Forum::Test::users;

{
    t::lib::CPAN::Forum::Test::setup_database();
    ok(-e $ENV{CPAN_FORUM_DB_FILE});
    BEGIN { $tests += 1; }
}


my $w_admin = Test::WWW::Mechanize->new;
my $w_user  = Test::WWW::Mechanize->new;
my $w_guest = Test::WWW::Mechanize->new;
my $url     = $ENV{CPAN_FORUM_TEST_URL};
$url =~ s{/+$}{};

my %config = read_config();
sub read_config {
    my %c;
    open my $in, '<', "t/CONFIG" or die;
    while (my $line = <$in>) {
        chomp $line;
        my ($k, $v) = split /=/, $line;
        $c{$k} = $v;
    }
    return %c;
}

#{
#    my @session_files = glob "/tmp/cgisess_*";
#    is (@session_files, 0);
#    BEGIN { $tests += 1; }
#}

{
    $w_admin->get_ok($url);
    $w_admin->content_like(qr{CPAN Forum});
    is($w_admin->cookie_jar->as_string, '');


    $w_admin->follow_link_ok({ text => 'login' });
    $w_admin->content_like(qr{Login});
    $w_admin->content_like(qr{Nickname});
#    my @session_files = glob "/tmp/cgisess_*";
#    is(@session_files, 1);
    my $cookie = '';
    my $cookie_jar = $w_admin->cookie_jar->as_string;
    if ($cookie_jar =~ /cpanforum=(\w+)/) {
        $cookie = $1;
    }
#    is($session_files[0], "/tmp/cgisess_$cookie");

    # submit form without values
    $w_admin->submit_form();
    $w_admin->content_like(qr{Need both nickname and password.});

    my $new_cookie = $w_admin->cookie_jar->as_string;
    
    # somtimes the seconds don't match and fail the test, getting rid of the time:
    $cookie_jar =~ s/\d\d:\d\d:\d\dZ//;
    $new_cookie =~ s/\d\d:\d\d:\d\dZ//;
    is($new_cookie, $cookie_jar);
    #diag $w_admin->cookie_jar->as_string;

    # submit form without password
    $w_admin->submit_form(
        fields => {
            nickname => $config{username},
        },
    );
    $w_admin->content_like(qr{Need both nickname and password.});
    $w_admin->content_like(qr{$config{username}});

    # submit form with bad password
    $w_admin->submit_form(
        fields => {
            nickname => $config{username},
            password => 'bad_assword',
        },
    );
    $w_admin->content_like(qr{Login failed.});
    $w_admin->content_like(qr{$config{username}});
    $w_admin->content_unlike(qr{bad_password});


    $w_admin->submit_form(
        fields => {
            nickname => $config{username},
            password => $config{password},
        },
    );
    $w_admin->content_like(qr{You are logged in as.*$config{username}});
    BEGIN { $tests += 14; }
}

#{
#    my @session_files = glob "/tmp/cgisess_*";
#    is (@session_files, 1);
#    BEGIN { $tests += 1; }
#}


{
    my $user = t::lib::CPAN::Forum::Test::register_user(0);
    #explain $user;
    $w_user->get_ok($url);
    $w_user->content_like(qr{CPAN Forum});
    $w_user->follow_link_ok({ text => 'login' });
    $w_user->content_like(qr{Login});

    $w_user->submit_form(
        fields => {
            nickname => $user->{username},
            password => $user->{password},
        },
    );
    $w_user->content_like(qr{You are logged in as.*$users[0]{username}});

    BEGIN { $tests += 5; }

}


{
    my $user
        = CPAN::Forum::DB::Users->info_by( username => $users[0]{username} );
    #explain $user;
    $w_guest->get_ok($url);
    $w_guest->content_like(qr{CPAN Forum});
    $w_guest->get_ok("$url/dist/Acme-Bleach");
    $w_guest->content_like(qr{subforum of Acme-Bleach});
    $w_guest->follow_link_ok({ text => 'new post' });

    # TODO check if this is the login form

    # next call causes the warning when running with -w
    $w_guest->submit_form(
        fields => {
            nickname => $user->{username},
            password => $user->{password},
        },
    );

    # this seem to be ok when done with real browser
    #diag $w_guest->content;
    $w_guest->content_like(qr{Distribution: Acme-Bleach});
    $w_guest->follow_link_ok({ text => 'logout' });

    BEGIN { $tests += 7; }
}

{
    $w_user->get_ok($url);
    $w_user->content_like(qr{CPAN Forum});
    $w_user->get_ok("$url/dist/Acme-Bleach");
    $w_user->content_like(qr{Acme-Bleach});
    $w_user->follow_link_ok({ text => 'new post' });
    $w_user->content_like(qr{Distribution: Acme-Bleach});

    BEGIN { $tests += 6; }
}

my @input_fields;
BEGIN { @input_fields = (
        ['allposts__all',    'checkbox',  'HTML::Form::ListInput',   undef],
        ['starters__all',    'checkbox',  'HTML::Form::ListInput',   undef],
        ['followups__all',   'checkbox',  'HTML::Form::ListInput',   undef],
#        ['allposts__new',    'checkbox',  'HTML::Form::ListInput',   undef],
#        ['starters__new',    'checkbox',  'HTML::Form::ListInput',   undef],
#        ['followups__new',   'checkbox',  'HTML::Form::ListInput',   undef],
#        ['type',             'option',    'HTML::Form::ListInput',   ''],
        ['rm',               'hidden',    'HTML::Form::TextInput',   'update_subscription'],
        ['gids',             'hidden',    'HTML::Form::TextInput',   '_all'],
        ['submit',           'submit',    'HTML::Form::SubmitInput', 'Update'],
#        ['name',             'text',      'HTML::Form::TextInput',   ''],
    );
}

{
    $w_user->follow_link_ok({ text => 'home' });
    $w_user->follow_link_ok({ text => 'mypan' });
    $w_user->content_like(qr{Personal configuration of}); # fname lname (username)
    my ($form) = $w_user->forms;
    isa_ok($form, 'HTML::Form');
    is($form->method, 'POST');
    is($form->action, "$url/");
    check_form($form, \@input_fields);

    BEGIN { $tests += 6 + 1+@input_fields*2; }
}


{
    # submit without any changes
    $w_user->submit_form();
    $w_user->content_like(qr{Your subscriptions were successfully updated.});
    $w_user->content_like(qr{You can look at them here:});
    $w_user->follow_link_ok({ text => 'subscription information' });
    my ($form) = $w_user->forms;
    check_form($form, \@input_fields);
    
    BEGIN { $tests += 3 +  1+@input_fields*2 }
}

# set the flags of all modules
foreach my $i (0..2) {
    my $input = $w_user->current_form->find_input( $input_fields[$i][0] );
    $input->check;
    $w_user->submit_form();
    $w_user->content_like(qr{Your subscriptions were successfully updated.});
    $w_user->content_like(qr{You can look at them here:});
    $w_user->follow_link_ok({ text => 'subscription information' });
    $w_user->content_unlike(qr{Acme-Bleach});
    my ($form) = $w_user->forms;
    $input_fields[$i][3] = 'on';
    check_form($form, \@input_fields);
    # TODO: check it in the database as well....    

    BEGIN { $tests += 3*(4 + 1 +@input_fields*2) }
}

# reset the flags of all modules
foreach my $i (0..2) {
    my $input = $w_user->current_form->find_input( $input_fields[$i][0] );
    $input->value(undef);
    $w_user->submit_form();
    $w_user->content_like(qr{Your subscriptions were successfully updated.});
    $w_user->content_like(qr{You can look at them here:});
    $w_user->follow_link_ok({ text => 'subscription information' });
    $w_user->content_unlike(qr{Acme-Bleach});
    my ($form) = $w_user->forms;
    $input_fields[$i][3] = undef;
    check_form($form, \@input_fields);
    # TODO: check it in the database as well....    

    BEGIN { $tests += 3*(4 + 1+@input_fields*2) }
}

# We don't have free text form on the mypan page now
{
    is($w_user->current_form->find_input('name'), undef, 'no free text input on mypan page');
    BEGIN { $tests += 1 }
}

#my $input_ref;
#{
#    $w_user->current_form->find_input('name')->value( 'Acme-Bleach' );
#    $w_user->current_form->find_input('type')->value( 'Distribution' );
#    $w_user->current_form->find_input('allposts__new')->check;
#    $w_user->submit_form();
#    $w_user->content_like(qr{Your subscriptions were successfully updated.});
#    $w_user->content_like(qr{You can look at them here:});
#    $w_user->follow_link_ok({ text => 'subscription information' });
#    my ($form) = $w_user->forms;
#    $input_ref = dclone(\@input_fields);
#    # 3 is the id number of Acme-Bleach
#    push @$input_ref,
#        ['allposts_3',    'checkbox',  'HTML::Form::ListInput',   'on'],
#        ['starters_3',    'checkbox',  'HTML::Form::ListInput',   undef],
#        ['followups_3',   'checkbox',  'HTML::Form::ListInput',   undef];
#    $input_ref->[8][3] = '_all,3';
#    check_form($form, $input_ref);
#    # TODO: check it in the database as well....    
#
#    BEGIN { $tests += (4 + (@input_fields+3)*2) }
#}

#my $input_ref2;
#{
#    $w_user->current_form->find_input('name')->value( 'MARKSTOS' );
#    $w_user->current_form->find_input('type')->value( 'PAUSEID' );
#    $w_user->current_form->find_input('starters__new')->check;
#    $w_user->submit_form();
#    $w_user->content_like(qr{Your subscriptions were successfully updated.});
#    $w_user->content_like(qr{You can look at them here:});
#    $w_user->follow_link_ok({ text => 'subscription information' });
#    my ($form) = $w_user->forms;
#    my $input_ref2 = dclone($input_ref);
#    # 2 is the id number of MARKSTOS
#    push @$input_ref2,
#        ['allposts__2',    'checkbox',  'HTML::Form::ListInput',   undef],
#        ['starters__2',    'checkbox',  'HTML::Form::ListInput',   'on'],
#        ['followups__2',   'checkbox',  'HTML::Form::ListInput',   undef];
#    $input_ref2->[8][3] = '_all,_2,3';
#    check_form($form, $input_ref2);
#    # TODO: check it in the database as well....    
#
#    BEGIN { $tests += (4 + (@input_fields+6)*2) }
#}


=pod
sqlite> select * from groups;
1|ABI||3|0.01|1||
2|CGI-Application-ValidateRM||3|1.12|2||
3|Acme-Bleach||3|1.12|3||
4|CGI-Application||3|3.22|2||
5|CGI-Application-Session||3|0.03|4||
sqlite> select * from authors;
1|MALAY
2|MARKSTOS
3|DCONWAY
4|CEESHEK
=cut


sub check_form {
    my ($form, $input_fields_ref, $diag) = @_;
    foreach my $i (@$input_fields_ref) {
        my ($name, $type, $obj, $value) = @$i;
        my $input = $form->find_input( $name, $type);
        isa_ok($input, $obj, "$name is $obj") or next;
        if (defined $value) {
            is($input->value, $value, "$name is $value");
        } else {
            ok(!(defined $input->value), "$name is undef") 
                or diag "$name is '" . $input->value . "'";
        }
    }
    my @inputs = $form->inputs;
    is(@inputs, scalar @$input_fields_ref);
    if ($diag) {
        foreach my $i (@inputs) {    diag $i->name; }
    }
}

