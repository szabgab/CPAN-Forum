#!/usr/bin/perl

use strict;
use warnings;

use Storable qw(dclone);
use Test::Most;

plan skip_all => 'Need CPAN_FORUM_TEST_DB and CPAN_FORUM_TEST_USER and CPAN_FORUM_LOGFILE'
	if not $ENV{CPAN_FORUM_TEST_DB}
		or not $ENV{CPAN_FORUM_TEST_USER}
		or not $ENV{CPAN_FORUM_LOGFILE};

eval "use Test::NoWarnings";

my $tests;
plan tests => $tests + 1;

bail_on_fail;

use CPAN::Forum::Daemon;

use t::lib::CPAN::Forum::Test;
my @users   = @t::lib::CPAN::Forum::Test::users;
my $w_admin = t::lib::CPAN::Forum::Test::get_mech();
my $w_user  = t::lib::CPAN::Forum::Test::get_mech();
my $w_guest = t::lib::CPAN::Forum::Test::get_mech();

my $year = 1900 + ( localtime() )[5];

$ENV{CPAN_FORUM_URL} = $ENV{CPAN_FORUM_TEST_URL}; # the Notify in the daemon needs this

{
	t::lib::CPAN::Forum::Test::setup_database();

	#ok(-e $ENV{CPAN_FORUM_DB_FILE});
	#BEGIN { $tests += 1; }
}


my $url = $ENV{CPAN_FORUM_TEST_URL};
$url =~ s{/+$}{};

#{
#    my @session_files = glob "/tmp/cgisess_*";
#    is (@session_files, 0);
#    BEGIN { $tests += 1; }
#}

{
	$w_admin->get_ok($url);
	$w_admin->content_like(qr{CPAN Forum});
	is( $w_admin->cookie_jar->as_string, '' );


	$w_admin->follow_link_ok( { text => 'login' } );
	$w_admin->content_like(qr{Login});
	$w_admin->content_like(qr{Nickname});

	#    my @session_files = glob "/tmp/cgisess_*";
	#    is(@session_files, 1);
	my $cookie     = '';
	my $cookie_jar = $w_admin->cookie_jar->as_string;
	if ( $cookie_jar =~ /cpanforum=(\w+)/ ) {
		$cookie = $1;
	}

	#    is($session_files[0], "/tmp/cgisess_$cookie");

	diag("Try to login without filling username or password");
	$w_admin->submit_form(
		form_name => 'login',
	);
	$w_admin->content_like(qr{Need both nickname and password.});

	my $new_cookie = $w_admin->cookie_jar->as_string;

	# somtimes the seconds don't match and fail the test, getting rid of the time:
	$cookie_jar =~ s/\d\d:\d\d:\d\dZ//;
	$new_cookie =~ s/\d\d:\d\d:\d\dZ//;
	is( $new_cookie, $cookie_jar );

	#diag $w_admin->cookie_jar->as_string;

	diag("Try to login with username but without password");
	$w_admin->submit_form(
		form_name => 'login',
		fields => {
			nickname => $t::lib::CPAN::Forum::Test::admin{username},
		},
	);
	$w_admin->content_like(qr{Need both nickname and password.});
	$w_admin->content_like(qr{$t::lib::CPAN::Forum::Test::admin{username}});

	diag("Try to login with correct username but with bad password");
	$w_admin->submit_form(
		form_name => 'login',
		fields => {
			nickname => $t::lib::CPAN::Forum::Test::admin{username},
			password => 'bad_assword',
		},
	);
	$w_admin->content_like(qr{Login failed.});
	$w_admin->content_like(qr{$t::lib::CPAN::Forum::Test::admin{username}});
	$w_admin->content_unlike(qr{bad_password});

	diag("Try to login with admin username and admin password");
	$w_admin->submit_form(
		form_name => 'login',
		fields => {
			nickname => $t::lib::CPAN::Forum::Test::admin{username},
			password => $t::lib::CPAN::Forum::Test::admin{password},
		},
	);
	$w_admin->content_like(qr{You are logged in as.*$t::lib::CPAN::Forum::Test::admin{username}});
	BEGIN { $tests += 14; }
}

#{
#    my @session_files = glob "/tmp/cgisess_*";
#    is (@session_files, 1);
#    BEGIN { $tests += 1; }
#}

my $user;
{
	diag("Login as a regular user");
	$user = t::lib::CPAN::Forum::Test::register_user(0);

	#explain $user;
	$w_user->get_ok($url);
	$w_user->content_like(qr{CPAN Forum});
	$w_user->follow_link_ok( { text => 'login' } );
	$w_user->content_like(qr{Login});

	$w_user->submit_form(
		form_name => 'login',
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

	#explain $user;
	$w_guest->get_ok($url);
	$w_guest->content_like(qr{CPAN Forum});
	$w_guest->get_ok("$url/dist/Acme-Bleach");
	$w_guest->content_like(qr{subforum of Acme-Bleach});
	$w_guest->follow_link_ok( { text => 'new post' } );

	# TODO check if this is the login form
	$w_guest->content_like(qr{In order to post on this site});

	$w_guest->submit_form(
		form_name => 'login',
		fields => {
			nickname => $user->{username},
			password => $user->{password},
		},
	);

	# this seem to be ok when done with real browser
	#diag $w_guest->content;
	$w_guest->content_like(qr{Distribution: Acme-Bleach});
	$w_guest->follow_link_ok( { text => 'logout' } );

	BEGIN { $tests += 8; }
}

{
	$w_user->get_ok($url);
	$w_user->content_like(qr{CPAN Forum});
	$w_user->get_ok("$url/dist/Acme-Bleach");
	$w_user->content_like(qr{Acme-Bleach});
	$w_user->follow_link_ok( { text => 'new post' } );
	$w_user->content_like(qr{Distribution: Acme-Bleach});

	BEGIN { $tests += 6; }
}

my @input_fields;

BEGIN {
	@input_fields = (
		[ 'allposts__all',  'checkbox', 'HTML::Form::ListInput', undef ],
		[ 'starters__all',  'checkbox', 'HTML::Form::ListInput', undef ],
		[ 'followups__all', 'checkbox', 'HTML::Form::ListInput', undef ],

		#        ['allposts__new',    'checkbox',  'HTML::Form::ListInput',   undef],
		#        ['starters__new',    'checkbox',  'HTML::Form::ListInput',   undef],
		#        ['followups__new',   'checkbox',  'HTML::Form::ListInput',   undef],
		#        ['type',             'option',    'HTML::Form::ListInput',   ''],
		[ 'rm',     'hidden', 'HTML::Form::TextInput',   'update_subscription' ],
		[ 'gids',   'hidden', 'HTML::Form::TextInput',   '_all' ],
		[ 'submit', 'submit', 'HTML::Form::SubmitInput', 'Update' ],

		#        ['name',             'text',      'HTML::Form::TextInput',   ''],
	);
}

{
	diag("Subscribe to notification on All entries");
	$w_user->follow_link_ok( { text => 'home' } );
	$w_user->follow_link_ok( { text => 'mypan' } );
	$w_user->content_like(qr{Personal configuration of}); # fname lname (username)
	my ($sf, $form) = $w_user->forms;
	isa_ok( $form, 'HTML::Form' );
	is( $form->method, 'POST' );
	is( $form->action, "$url/" );
	check_form( $form, \@input_fields );

	BEGIN { $tests += 6 + 1 + @input_fields * 2; }
}


{

	# submit without any changes
	$w_user->submit_form(
		form_name => 'subscriptions',
	);
	$w_user->content_like(qr{Your subscriptions were successfully updated.});
	$w_user->content_like(qr{You can look at them here:});
	$w_user->follow_link_ok( { text => 'subscription information' } );
	my ($sf, $form) = $w_user->forms;
	check_form( $form, \@input_fields );

	BEGIN { $tests += 3 + 1 + @input_fields * 2 }
}

# set the flags of all modules
foreach my $i ( 0 .. 2 ) {
	$w_user->form_name('subscriptions');
	my $input = $w_user->current_form->find_input( $input_fields[$i][0] );
	$input->check;
	$w_user->submit_form(
		form_name => 'subscriptions',
	);
	$w_user->content_like(qr{Your subscriptions were successfully updated.});
	$w_user->content_like(qr{You can look at them here:});
	$w_user->follow_link_ok( { text => 'subscription information' } );
	$w_user->content_unlike(qr{Acme-Bleach});
	my ($sf, $form) = $w_user->forms;
	$input_fields[$i][3] = 'on';
	check_form( $form, \@input_fields );

	# TODO: check it in the database as well....

	BEGIN { $tests += 3 * ( 4 + 1 + @input_fields * 2 ) }
}

my @posts;
BEGIN {
	@posts = (
		{
			subject => 'A new subject',
			text    => "This is supposed to be a posting",
		},
		{
			subject => 'Another title',
			text    => "Content of second post",
		},
		{
			subject => 'title of 3rd post',
			text    => "Content of third post",
		},
		{
			subject => 'This is a reponse post',
			text    => "Should be seen in a thred as the second message.",
		},
	);
}

my @post_preview_input_fields;
my @post_submit_input_fields;

BEGIN {
	@post_preview_input_fields = (
		[ 'rm',           'hidden', 'HTML::Form::TextInput', 'process_post' ],
		[ 'new_group_id', 'hidden', 'HTML::Form::TextInput', '2' ],           # really can we know this number for sure?
		[ 'new_parent',   'hidden', 'HTML::Form::TextInput', '' ],
		[ 'new_subject',  'text',   'HTML::Form::TextInput', '' ],
		[ 'new_text',       'textarea', 'HTML::Form::TextInput',   '' ],
		[ 'preview_button', 'submit',   'HTML::Form::SubmitInput', 'Preview' ],
		[ 'preview_button', 'submit',   'HTML::Form::SubmitInput', 'Preview' ], # there are two preview buttons
	);
	@post_submit_input_fields = (
		[ 'rm',           'hidden', 'HTML::Form::TextInput', 'process_post' ],
		[ 'new_group_id', 'hidden', 'HTML::Form::TextInput', '2' ],           # really can we know this number for sure?
		[ 'new_parent',   'hidden', 'HTML::Form::TextInput', '' ],
		[ 'new_subject',    'text',     'HTML::Form::TextInput',   $posts[0]{subject} ],
		[ 'new_text',       'textarea', 'HTML::Form::TextInput',   $posts[0]{text} ],
		[ 'preview_button', 'submit',   'HTML::Form::SubmitInput', 'Preview' ],
		[ 'preview_button', 'submit', 'HTML::Form::SubmitInput', 'Preview' ], # there are two preview buttons
		[ 'submit_button',  'submit', 'HTML::Form::SubmitInput', 'Submit' ],
		[ 'submit_button',  'submit', 'HTML::Form::SubmitInput', 'Submit' ],  # there are two submit buttons
	);

}

{
	$w_guest->get_ok("$url/rss/all");
	$w_guest->content_like(qr{<title>No posts yet</title>});
	$w_guest->get_ok("$url/atom/all");
	$w_guest->content_like(qr{<title>No posts yet</title>});

	$w_guest->get_ok("$url/rss/threads");
	$w_guest->content_like(qr{<title>No posts yet</title>});
	$w_guest->get_ok("$url/atom/threads");
	$w_guest->content_like(qr{<title>No posts yet</title>});

	$w_guest->get_ok("$url/rss/tags");
	$w_guest->content_like(qr{<title>No posts yet</title>});
	$w_guest->get_ok("$url/atom/tags");
	$w_guest->content_like(qr{<title>No posts yet</title>});

	#explain $w_guest->content;
	BEGIN { $tests += 3 * 4 }
}


{
	diag "Submit a post";
	is_deeply( \@CPAN::Forum::messages, [], 'no messages were sent so far' );
	$w_user->get_ok("$url/dist/Acme-Bleach");
	$w_user->content_like(qr{Be the first one to post a message in the subforum of Acme-Bleach});
	$w_user->follow_link_ok( { text => 'new post' } );
	$w_user->content_like(qr{Distribution: Acme-Bleach});
	$w_user->content_unlike(qr{Password:}); # not a login form
	$w_user->content_unlike(qr{Posted on});
	my ( $sf, $post_form1 ) = $w_user->forms;

	#$input_fields[$i][3] = undef;
	check_form( $post_form1, \@post_preview_input_fields );

	diag "Submit to Preview";
	$w_user->submit_form(
		form_name => 'editor',
		button      => 'preview_button',
		fields      => {
			new_subject => $posts[0]{subject},
			new_text    => $posts[0]{text},
		},
	);

	#diag $w_user->content;
	$w_user->content_like(qr{  Posted  \s+ on .* $year .* by .* $users[0]{username}  }sx);
	$w_user->content_like(qr{<b>Preview</b>});
	my ( $sf2, $post_form2 ) = $w_user->forms;
	check_form( $post_form2, \@post_submit_input_fields );

	is_deeply( \@CPAN::Forum::messages, [], 'no messages were sent so far' );
	diag "Submit for posting";
	$w_user->submit_form(
		form_name => 'editor',
		button      => 'submit_button',
	);

	$w_user->content_like( qr{messages in a total of 1} );
	#explain \@CPAN::Forum::messages;
	#is_deeply(\@CPAN::Forum::messages, [], 'no messages were sent so far');
	is( scalar(@CPAN::Forum::messages), 0, '0 message sent' );

	my $d = CPAN::Forum::Daemon->new;
	$d->run();
	is( scalar(@CPAN::Forum::messages), 1, '1 message sent by daemon' );
	like( $CPAN::Forum::messages[0]{Message}, qr{\($users[0]{username}\) wrote:} );
	
	@CPAN::Forum::messages = ();
	$d->run();
	is( scalar(@CPAN::Forum::messages), 0, 'no more messages sent' );

	# TODO check the e-mail message more in details!

	BEGIN { $tests += 15 + 1 + @post_preview_input_fields * 2 + 1 + @post_submit_input_fields * 2 }
}

#{
#	$w_user->content_like(qr{Trying to submit posts too quickly .* Please wait 10 more seconds before posting again}s);
#}

{
	@CPAN::Forum::messages = ();
	CPAN::Forum::DB::Configure->set_field_value( 'flood_control_time_limit', 0 );

	foreach my $i (1..2) {
		$w_user->get_ok("$url/dist/Acme-Bleach");
		$w_user->content_like(qr{Post a message in the subforum of Acme-Bleach});
		$w_user->follow_link_ok( { text => 'new post' } );

		$w_user->submit_form(
			form_name => 'editor',
			button      => 'preview_button',
			fields      => {
				new_subject => $posts[$i]{subject},
				new_text    => $posts[$i]{text},
			},
		);

		$w_user->content_like(qr{  Posted  \s+ on .* $year .* by .* $users[0]{username}  }sx);
		$w_user->content_like(qr{<b>Preview</b>});
		$w_user->submit_form(
			form_name => 'editor',
			button      => 'submit_button',
		);
#		diag $w_user->content;
		my $t = $i+1;
		$w_user->content_unlike(qr{Trying to submit posts too quickly});
		$w_user->content_like( qr{messages in a total of $t} );
	}
	$w_user->follow_link_ok( { text => $posts[0]{subject} });
	$w_user->content_like( qr{$posts[0]{text}} );
	$w_user->follow_link_ok( { text => 'Write a response' });
	$w_user->submit_form(
		form_name => 'editor',
		button      => 'preview_button',
		fields      => {
			new_subject => $posts[3]{subject},
			new_text    => $posts[3]{text},
		},
	);
	$w_user->content_like(qr{<b>Preview</b>});
	$w_user->submit_form(
		form_name => 'editor',
		button      => 'submit_button',
	);

	#diag $w_user->content;


	#explain \@CPAN::Forum::messages;
	#is_deeply(\@CPAN::Forum::messages, [], 'no messages were sent so far');
	is( scalar(@CPAN::Forum::messages), 0, '0 message sent' );
	
	# TODO check the database

	my $d = CPAN::Forum::Daemon->new;
	$d->run();
	is( scalar(@CPAN::Forum::messages), 3, '3 message sent by daemon' );
	#explain @CPAN::Forum::messages;
	#like( $CPAN::Forum::messages[0]{Message}, qr{\($users[0]{username}\) wrote:} );
	
	@CPAN::Forum::messages = ();
	$d->run();
	is( scalar(@CPAN::Forum::messages), 0, 'no more messages sent' );
	
	BEGIN { $tests += 7*2+ 7 };
}

{
	diag('Check various broken URLs');
	$w_guest->get_ok("$url/posts/100");
	# TODO maybe the error should contain some other text?
	$w_guest->content_unlike(qr{Something went wrong here});
	$w_guest->content_like(qr{No such post});


	$w_guest->get_ok("$url/posts/borg");
	#diag $w_guest->content;
	$w_guest->content_unlike(qr{Something went wrong here});
	$w_guest->content_like(qr{Invalid request});
	
	BEGIN { $tests += 2*3 };
}


{
	diag('Check new post on the front page and on its own');
	$w_guest->get_ok($url);
	$w_guest->content_like(qr{Acme-Bleach});
	$w_guest->content_like(qr{$posts[0]{subject}});
	$w_guest->content_like(qr{$year});
	
	$w_guest->follow_link_ok( { text => $posts[0]{subject} } );
	$w_guest->content_like(qr{Acme-Bleach});
	$w_guest->content_like(qr{$posts[0]{subject}});
	$w_guest->content_like(qr{  Posted  \s+ on .* $year .* by .* $users[0]{username}  }sx);
	
	BEGIN { $tests += 4+4 }
}

{
	diag('Check new post in the rss and atom feeds');
	$w_guest->get_ok("$url/rss/all");
	$w_guest->content_unlike(qr{<title>No posts yet</title>});
	$w_guest->content_like(qr{<title>\[Acme-Bleach\] $posts[0]{subject}</title>});
	$w_guest->content_like(qr{<link>$url.*/posts/1</link>});

	$w_guest->get_ok("$url/atom/all");
	$w_guest->content_unlike(qr{<title>No posts yet</title>});
	$w_guest->content_like(qr{<title>\[Acme-Bleach\] $posts[0]{subject}</title>});
	$w_guest->content_like(qr{<link href="$url.*/posts/1"/>});

	# TODO, should not these link to the thread instead?
	$w_guest->get_ok("$url/rss/threads");

	#diag $w_guest->content;
	$w_guest->content_unlike(qr{<title>No posts yet</title>});
	$w_guest->content_like(qr{<title>\[Acme-Bleach\] $posts[1]{subject}</title>});
	$w_guest->content_like(qr{<link>$url.*/posts/2</link>});

	$w_guest->get_ok("$url/atom/threads");
	$w_guest->content_unlike(qr{<title>No posts yet</title>});
	$w_guest->content_like(qr{<title>\[Acme-Bleach\] $posts[1]{subject}</title>});
	$w_guest->content_like(qr{<link href="$url.*/posts/2"/>});

	#
	#    $w_guest->get_ok("$url/rss/tags");
	#    $w_guest->content_like(qr{<title>No posts yet</title>});
	#    $w_guest->get_ok("$url/atom/tags");
	#    $w_guest->content_like(qr{<title>No posts yet</title>});

	BEGIN { $tests += 4 * 4 }
}




my @update_tags;

BEGIN {
	@update_tags = (

		#        ['rm',               'hidden',    'HTML::Form::TextInput',   'process_post'],  #  where is the run mode?
		[ 'what',     'hidden', 'HTML::Form::TextInput', 'tags' ],
		[ 'group_id', 'hidden', 'HTML::Form::TextInput', '2' ],   # really can we know this number for sure?
		[ 'new_tags', 'text',   'HTML::Form::TextInput', '' ],
		[ 'update_button', 'submit', 'HTML::Form::SubmitInput', 'Update my tags' ],
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

	my ( $sf, $tags_form ) = $w_user->forms;
	check_form( $tags_form, \@update_tags );

	$w_user->submit_form(
		form_name => 'update_tags',
		button      => 'update_button',
		fields      => {
			new_tags => 'one_word, two words',
		},
	);
	$w_user->content_like(qr{Tags on.*Acme-Bleach.*were updated}s);
	$w_user->follow_link_ok( { text => 'all the tags' } );
	$w_user->follow_link_ok( { text => 'two words' } );
	$w_user->content_unlike(qr{Something went wrong here});
	$w_user->follow_link_ok( { text => 'Acme-Bleach' } );

	$w_user->follow_link_ok( { text => 'one_word' } );
	$w_user->back;
	$w_user->follow_link_ok( { text => 'two words' } );

	$w_guest->get_ok("$url/dist/Acme-Bleach");
	$w_guest->follow_link_ok( { text => 'one_word' } );
	$w_guest->back;
	$w_guest->follow_link_ok( { text => 'two words' } );

	BEGIN { $tests += 8 + 1 + @update_tags * 2 + 10; }
}


diag("Unsubscribe form all notifications");
$w_user->get_ok("$url/mypan");
foreach my $i ( 0 .. 2 ) {
	$w_user->form_name('subscriptions');
	my $input = $w_user->current_form->find_input( $input_fields[$i][0] );
	$input->value(undef);
	$w_user->submit_form(
		form_name => 'subscriptions',
	);
	$w_user->content_like(qr{Your subscriptions were successfully updated.});
	$w_user->content_like(qr{You can look at them here:});
	$w_user->follow_link_ok( { text => 'subscription information' } );
	$w_user->content_unlike(qr{Acme-Bleach});
	my ($sf, $form) = $w_user->forms;
	$input_fields[$i][3] = undef;
	check_form( $form, \@input_fields );

	# TODO: check it in the database as well....

	BEGIN { $tests += 1 + 3 * ( 4 + 1 + @input_fields * 2 ) }
}

# We don't have free text form on the mypan page now
{
	is( $w_user->current_form->find_input('name'), undef, 'no free text input on mypan page' );
	BEGIN { $tests += 1 }

}

{
	diag('no such page');
	$w_guest->get_ok("$url/some_other_page");
	$w_guest->content_like(qr{No such Page});
	BEGIN { $tests += 2 }
}

#{
#	diag('reset password');
#	my $w_user2  = t::lib::CPAN::Forum::Test::get_mech();
#	$w_user2->get_ok("$url/reset_password_form");
#	$w_user2->content_like( qr{Please fill out the new password} );
#	#diag($w_user2->content);
#	BEGIN { $tests += 2 }
#}


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


sub check_form {
	my ( $form, $input_fields_ref, $diag ) = @_;
	local $Test::Builder::Level =  $Test::Builder::Level + 1;
	foreach my $i (@$input_fields_ref) {
		my ( $name, $type, $obj, $value ) = @$i;

		#next if not $name; # skip this test
		my $input = $form->find_input( $name, $type );
		isa_ok( $input, $obj, "$name is $obj" ) or do {
			diag $input;
			next;
		};
		if ( defined $value ) {
			is( $input->value, $value, "$name is $value" );
		} else {
			ok( !( defined $input->value ), "$name is undef" )
				or diag "$name is '" . $input->value . "'";
		}
	}
	my @inputs = $form->inputs;
	is( @inputs, scalar @$input_fields_ref ) or explain \@inputs;
	if ($diag) {
		foreach my $i (@inputs) { diag $i->name; }
	}
}

