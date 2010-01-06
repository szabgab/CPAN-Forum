#!/usr/bin/perl

use strict;
use warnings;

use Storable qw(dclone);
use Test::Most;

plan skip_all => 'Need CPAN_FORUM_TEST_DB and CPAN_FORUM_TEST_USER and CPAN_FORUM_LOGFILE' 
	if not $ENV{CPAN_FORUM_TEST_DB} or not $ENV{CPAN_FORUM_TEST_USER} or not $ENV{CPAN_FORUM_LOGFILE};

my $tests;
plan tests => $tests;

#bail_on_fail;

use t::lib::CPAN::Forum::Test;
my @users = @t::lib::CPAN::Forum::Test::users;
my $w_admin = t::lib::CPAN::Forum::Test::get_mech();
my $w_user  = t::lib::CPAN::Forum::Test::get_mech();
my $w_guest = t::lib::CPAN::Forum::Test::get_mech();

{
    t::lib::CPAN::Forum::Test::setup_database();
    #ok(-e $ENV{CPAN_FORUM_DB_FILE});
    #BEGIN { $tests += 1; }
}


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

    diag("Try to login without filling username or password");
    $w_admin->submit_form();
    $w_admin->content_like(qr{Need both nickname and password.});

    my $new_cookie = $w_admin->cookie_jar->as_string;
    
    # somtimes the seconds don't match and fail the test, getting rid of the time:
    $cookie_jar =~ s/\d\d:\d\d:\d\dZ//;
    $new_cookie =~ s/\d\d:\d\d:\d\dZ//;
    is($new_cookie, $cookie_jar);
    #diag $w_admin->cookie_jar->as_string;

    diag("Try to login with username but without password");
    $w_admin->submit_form(
        fields => {
            nickname => $config{username},
        },
    );
    $w_admin->content_like(qr{Need both nickname and password.});
    $w_admin->content_like(qr{$config{username}});

    diag("Try to login with correct username but with bad password");
    $w_admin->submit_form(
        fields => {
            nickname => $config{username},
            password => 'bad_assword',
        },
    );
    $w_admin->content_like(qr{Login failed.});
    $w_admin->content_like(qr{$config{username}});
    $w_admin->content_unlike(qr{bad_password});

	diag("Try to login with admin username and admin password");
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
	diag("Login as a regular user");
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


# the next can be probably removed or if we could check here that no e-mail is sent after
# posting
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
	diag("Subscribe to notification on All entries");
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

my @post_preview_input_fields;
my @post_submit_input_fields;
BEGIN { 
	@post_preview_input_fields = (
        ['rm',               'hidden',    'HTML::Form::TextInput',   'process_post'],
        ['new_group_id',     'hidden',    'HTML::Form::TextInput',   '3'],   # really can we know this number for sure?
        ['new_parent',       'hidden',    'HTML::Form::TextInput',   ''],
        ['new_subject',      'text',      'HTML::Form::TextInput',   ''],
        ['new_text',         'textarea',  'HTML::Form::TextInput',   ''],
        ['preview_button',   'submit',    'HTML::Form::SubmitInput', 'Preview'],
        ['preview_button',   'submit',    'HTML::Form::SubmitInput', 'Preview'], # there are two preview buttons
    );
	@post_submit_input_fields = (
        ['rm',               'hidden',    'HTML::Form::TextInput',   'process_post'],
        ['new_group_id',     'hidden',    'HTML::Form::TextInput',   '3'],   # really can we know this number for sure?
        ['new_parent',       'hidden',    'HTML::Form::TextInput',   ''],
        ['new_subject',      'text',      'HTML::Form::TextInput',   'A new subject'],
        ['new_text',         'textarea',  'HTML::Form::TextInput',   "This is supposed to be a posting"],
        ['preview_button',   'submit',    'HTML::Form::SubmitInput', 'Preview'],
        ['preview_button',   'submit',    'HTML::Form::SubmitInput', 'Preview'], # there are two preview buttons
        ['submit_button',    'submit',    'HTML::Form::SubmitInput', 'Submit'],
        ['submit_button',    'submit',    'HTML::Form::SubmitInput', 'Submit'], # there are two submit buttons
	);

}


{
    diag "Submit a post";
    is_deeply(\@CPAN::Forum::messages, [], 'no messages were sent so far');
    $w_user->get_ok("$url/dist/Acme-Bleach");
    $w_user->content_like(qr{Be the first one to post a message in the subforum of Acme-Bleach});
    $w_user->follow_link_ok({ text => 'new post' });
    $w_user->content_like(qr{Distribution: Acme-Bleach});
    $w_user->content_unlike(qr{Password:});  # not a login form
    $w_user->content_unlike(qr{Posted on});
    my ($serch_form1, $post_form1) = $w_user->forms;
    #$input_fields[$i][3] = undef;
    check_form($post_form1, \@post_preview_input_fields);

	diag "Submit to Preview";
    $w_user->submit_form(
		form_number => 2,
		button => 'preview_button',
        fields => {
            new_subject   => 'A new subject',
            new_text      => "This is supposed to be a posting",
        },
    );
    #diag $w_user->content;
    $w_user->content_like( qr{Posted on.*by.*$users[0]{username}}s );
    $w_user->content_like(qr{<b>Preview</b>});
    my ($serch_form2, $post_form2) = $w_user->forms;
    check_form($post_form2, \@post_submit_input_fields);

    is_deeply(\@CPAN::Forum::messages, [], 'no messages were sent so far');
	diag "Submit for posting";
    $w_user->submit_form(
		form_number => 2,
		button => 'submit_button',
    );
    #diag $w_user->content;
	#explain \@CPAN::Forum::messages;
    #is_deeply(\@CPAN::Forum::messages, [], 'no messages were sent so far');
    is(scalar(@CPAN::Forum::messages), 1, 'one message sent');
	like($CPAN::Forum::messages[0]{Message}, qr{\($users[0]{username}\) wrote:});
	# TODO check the e-mail message more in details!
    
    BEGIN { $tests += 12 + 1+@post_preview_input_fields*2  + 1+@post_submit_input_fields*2}
}


my @update_tags;
BEGIN { 
	@update_tags = (
#        ['rm',               'hidden',    'HTML::Form::TextInput',   'process_post'],  #  where is the run mode?
        ['what',     'hidden',    'HTML::Form::TextInput',   'tags'],
        ['group_id',       'hidden',    'HTML::Form::TextInput',   '3'],    # really can we know this number for sure?
        ['new_tags',      'text',      'HTML::Form::TextInput',   ''],
        ['update_button',   'submit',    'HTML::Form::SubmitInput', 'Update my tags'],
    );
}

{
	$w_user->get_ok("$url/tags/");
	$w_user->content_unlike(qr{Something went wrong here});

	$w_guest->get_ok("$url/tags/");
	$w_guest->content_unlike(qr{Something went wrong here});
	
	$w_user->get_ok("$url/dist/Acme-Bleach");
	$w_user->content_like(qr{Update my tags});
	
	$w_guest->get_ok("$url/dist/Acme-Bleach");
	$w_guest->content_unlike(qr{Update my tags});

	my ($search_form, $tags_form) = $w_user->forms;
	check_form($tags_form, \@update_tags);
	
	BEGIN { $tests += 8  + 1+@update_tags*2; }
}


diag("Unsubscribe form all notifications");
$w_user->get_ok("$url/mypan");
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

    BEGIN { $tests += 1+ 3*(4 + 1+@input_fields*2) }
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
		#next if not $name; # skip this test
        my $input = $form->find_input( $name, $type);
        isa_ok($input, $obj, "$name is $obj") or do {
			diag $input;
			next;
		};
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

