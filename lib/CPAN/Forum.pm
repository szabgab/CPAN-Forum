package CPAN::Forum;
use strict;
use warnings;
use 5.008;

our $VERSION = '0.18';

use base 'CGI::Application';

use base 'CPAN::Forum::RM::Author';
use base 'CPAN::Forum::RM::Dist';
use base 'CPAN::Forum::RM::Login';
use base 'CPAN::Forum::RM::Users';
use base 'CPAN::Forum::RM::Admin';
use base 'CPAN::Forum::RM::Other';
use base 'CPAN::Forum::RM::Notify';
use base 'CPAN::Forum::RM::Posts';
use base 'CPAN::Forum::RM::Search';
use base 'CPAN::Forum::RM::Subscriptions';
use base 'CPAN::Forum::RM::Tags';
use base 'CPAN::Forum::RM::UserAccounts';
use base 'CPAN::Forum::RM::Update';
use base 'CPAN::Forum::RM::Threads';

use CGI ();
use CGI::Application::Plugin::Session;
use CGI::Application::Plugin::TT;
use CGI::Application::Plugin::LogDispatch;
use Data::Dumper qw(Dumper);
use List::MoreUtils qw(any);
use POSIX qw();

use CPAN::Forum::DBI ();
use CPAN::Forum::DB::Configure ();
use CPAN::Forum::DB::Groups ();
use CPAN::Forum::DB::Posts ();
use CPAN::Forum::DB::Subscriptions ();
use CPAN::Forum::DB::Users ();
use CPAN::Forum::Tools ();
use CPAN::Forum::Markup ();

my $cookiename = "cpanforum";
my $STATUS_FILE;

my %errors = (
	"ERR no_less_sign"              => "No < sign in text",
	"ERR line_too_long"             => "Line too long",
	"ERR open_code_without_closing" => "open <code> tag without closing tag",
);

=head1 NAME

CPAN::Forum - Web forum application to discuss CPAN modules

=head1 SYNOPSIS

Visit L<http://cpanforum.com/>

=head1 DESCRIPTION

This is a Web forum application specifically designed to be used for
discussing CPAN modules. At one point it might be adapted to be a general
forum software but for now it is released in the hope that people
will help improving it and by that improving the 
L<http://cpanforum.com/> site.

=head2 Features

=over 4 

=item * Posting only by authenticated users.

=item * For registration a valid e-mail is required.

=item * Username and password should be in lowercase and unique.

=item * Every poster will have to give

=over 4

=item 1. name of the group

=item 2. Subject

=item 3. Content

=item 4. (Future) A unique id to the post and the post made in response to.
   
This reference id will be NULL for new posts. At the beginning responses will 
have to maintain group but can change the subject and will have to write new 
text.

=back 

=item * Later we might enable changing the group to a related group.

(e.g. a message about a module can get a response in a group to which this 
module belongs to)

=item * Later we might enable total random change in the groups.

=item * We make sure the links are search-engine friendly

  /dist/Dist-Name/
  /rss/
  /atom/
  
  /posts/ID  (link to a post)
  /threads/ID  (link to a thread)

=item * We provide RSS and Atom feed of the recent posts belonging to any of the groups.

=item * We'll provide search capability with restrictions to groups.

=back

=head1 Authentication

Shared authentication with auth.perl.org? I once tried to do this but then for 
some reason I could not finish the process. Maybe later we'll want to enable 
our users to use their auth.perl.org identity. Maybe we can do it also with 
PerlMonks. Right now we have our own registration and login mechanism.

=head1 INSTALLATION of a development environment

=head2 hosts

For local installations in /etc/hosts I added:

    127.0.0.1         test.cpanforum.local

That way, I can have a totally separate virtual host just for this application.

=head2 PostgreSQL

  $ sudo -u postgres psql postgres
  postgres=# CREATE ROLE forum_test_user LOGIN;
  postgres=# CREATE DATABASE cpanforum_test OWNER = forum_test_user;
  
  $ sudo vi /etc/postgresql/8.4/main/pg_hba.conf
  
Add:   local all forum_test_user trust

  $ sudo  /etc/init.d/postgresql-8.4 restart
 
 Now this should work:
 
   $ psql -U forum_test_user cpanforum_test

=head2 Apache

This is the configuration of my Apache server on my development machine. 
(Actually I have several of these and one of them is using mod_perl2.

  <VirtualHost *:80>
    ServerName   test.cpanforum.local
	
    SETENV CPAN_FORUM_LOGFILE /tmp/cpanforum_test.log
    SETENV CPAN_FORUM_DB cpanforum_test
    SETENV CPAN_FORUM_USER forum_test_user

    SETENV CPAN_FORUM_NOMAIL 1
    SETENV CPAN_FORUM_DEV 1

    DocumentRoot /home/gabor/work/cpan-forum/www
    Alias            /img       /home/gabor/work/cpan-forum/www/img
    Alias /pod  /home/gabor/.cpanforum/dist
    AliasMatch ^/dist/(.+/.+) /home/gabor/.cpanforum/dist/$1
    
    ScriptAliasMatch ^/(\w*)$  /home/gabor/work/cpan-forum/www/cgi/index.pl/$1
    ScriptAliasMatch ^/(.*/.*)  /home/gabor/work/cpan-forum/www/cgi/index.pl/$1
    DirectoryIndex              cgi/index.pl
  </VirtualHost>


=head2 Environment variables

in ~/.bashrc I have the following:

   export CPAN_FORUM_LOGFILE=/tmp/cpanforum_gabor.log
   export CPAN_FORUM_TEST_URL=http://test.cpanforum.local/
   export CPAN_FORUM_TEST_DB=cpanforum_test
   export CPAN_FORUM_TEST_USER=forum_test_user

=head2 Install the perl code

=head2 test the code

    perl Build.PL       - and make sure the prerequisites are installed
                          some of the can be installed using    sudo aptitude ...
                          for others I configured local::lib, installed them locally
                          and configured the Apache server to look at that by adding the following
                          to the configuration file of Apache:
              SETENV PERL5LIB /home/gabor/perl5/lib/perl5:/home/gabor/perl5/lib/perl5/x86_64-linux-gnu-thread-multi

    ./Build
    ./Build test

    chmod a+x www/cgi/index.pl


=head2 Setup and populate the database

    perl bin/setup.pl 
        --username testadmin              The user name of the administrator used on the web interface
        --email 'test\@perl.org.il'       The E-mail of the administrator.
        --password pw_of_testadmin        The password of the administrator.
        --from 'testforum\@perl.org.il'   The Email address to be used as the from address in the messages sent by the system.

        --dbname $ENV{CPAN_FORUM_DB} 
        --dbuser $ENV{CPAN_FORUM_USER}

You will be able to change all these values later from the web interface but 
we need to have the first values.

    
    perl bin/populate_cpan_forum.pl 
        --dbname $ENV{CPAN_FORUM_DB} 
        --dbuser $ENV{CPAN_FORUM_USER}

This will fetch a file from www.cpan.org and might take a few minutes to run.

=head1 PATH

The path to the root of the unzipped distribution is 
determined automatically by the cgi script or the mod_perl
handle. Path to lib/ and templates/ can be derived from it.

=head2 CPAN_FORUM_LOGFILE

Path to the log file.


=head2 CPAN_FORUM_DEV

Indicate that we are on a development machine. (No Google Analytics or advertisements)

=head2 CPAN_FORUM_TEST_URL

For some of the tests you'll have to set the CPAN_FORUM_TEST_URL environment 
variable to the URL where you installed the forum.

=head2 CPAN_FORUM_NO_MAIL

Turn off mail sending (for testing).


=head1 TODO

See the TODO file

=head1 Description

Subject field:
-  <= 80 chars
-  Can contain any characters, we'll escape them when showing on the web site
 
Text field:
- No restriction on line length, let the HTML handle that part
- The text is divided into areas of free text and marked sections

- Pages:
    new mesage:      EDITOR;          PREVIEW + EDITOR
    show:            POST
    response:        POST + EDITOR;   POST + PREVIEW + EDITOR

    thread:          P1 + P2 + .. Pn
    thread response: P1 + P2 + .. Pn + EDITOR;   \
    P1 + P2 + .. Pn + PREVIEW + EDITOR;

When the EDITOR comes up first the subject should be filled by the subject it
is answering to or empty for new message.
  
The PREVIEW and the EDITOR should be filled by the same information, though
within the editor we don't need the parent id and similar to be shown.


OK, so we have listing in places like

    /
    /dist/Distro-Name
    /users/USERNAME
    
    /all  Can be a name for all the posts so we don't need to put any other 
          information immediately after the first slash  maybe it should be 
          /home ?

    /dist/Distro-Name/start/count
    /all/start/count

    
We'll also have some search facility that will be a post operation and

    /posts/id          show a post      (show post         )
    /new_post/         start new post   (            editor with module list)
    /new_post/Module   start new post   (            editor  no  module list)
    /response_form/id  start a respones (show post + editor)


From the forms we have post methods so no need for URL munging
process_post  =>  (show previous post)? show editor + show preview

=over 4

A user can ask to be notified upon the following events per distribution.
subscriptions: uid, gid, (all), (starter), (participate)
1) All messages 

All the messages execute 
QUERY: select uid FROM subscription WHERE gid == disto and all. 

2) Thread starters
Thread starteres (where id=thread) execute 
QUERY: select uid FROM subscription WHERE gid == distro and starter

3) Followup messages in a thread he participated already
Every message (well, except thread starters) execute:
QUERY: select uid FROM subscription
- there is a post with the same thread id as of this post which was posted by a user which
has a subsciption (participate)


4) People who are not subscribed to All messages (1) when seeing an
interesting posting they can say: send me all followups.  uid, threadid

She can set up such notification on a per module basis or for all the modules.

After logging in the user can modify his "subscriptions" to such notifications.
The notification will be sent out from an e-mail address such as 
noreply@bla.com  which will discard any message sent to it. The message will contain
the text of the post, a link to the post_response page, a link to view the 
whole thread
and an e-mail address in case someone wants to complain/whatever.

=back

- Subscription (notify) management:

- /mypan will be the url to get and set all the configuration information.
It will list all your current subscriptions and you can enable/disable them.
Normally this will show only distributions you have some kind of a subscription.

In addition from /mypan there will be a way to ask to add a new subscription by selecting
the name of a module and the initial subscription parameters to it.

In addition when displaying the list of all the messages to a specific module, logged in users
will see their current subscription to this module (even if that is empty).

=head2 Notification

There is a boolean field on each post called "notified"
When adding a new post we set it to false which is the default value.
There is a daemon that checks the database for posts with "notified"  not TRUE.
Sends the notification messages and sets the bit to true.

=head2 Reset Lost Password

We generate a random string and save the random string as field in the junk table.
The value  will be { rm => 'resetpw', username => $username }  dumped using YAML::Tiny.
We send the random thing by mail to the user attached to a url.

When the user comes with the random string we can fetch the value and go to the 
resetpw run mode that shows a page with two empty password fields 
with the random string in a hidden fields on the page.

When the user submits the new password pair we look-up the random string again 
and check if the run mode is the one the user requested to execute. 
(Actually this is not the same run-mode)
If that's the one we update the password and remove the row from the junk table.

=head1 Schema

=over 4

=item configure

=item grouprelations

NOT USED

=item groups

 name   - name of the module (using - separator)
 gtype  - is
 status - NOT USED

Every CPAN module has an antry in this table.

=item posts

 gid
 uid
 parent
 thread
 hidden
 subject
 text
 date

=item sessions

Used for session management

=item subscriptions

 uid
 gid
 allposts
 starters
 followups
 announcements

=item usergroups

 name - name of the group

Currently we only have the 'admin' group

=item user_in_group

 uid - user id
 gid - group id

 Members of the usergroup.

=item users

 username - should be lower case, 
 password -
 email - should be kept in lower case 
 fname
 lname
 update_on_new_user - 
      TRUE/FALSE, should be only relevant for users in the 'admin' group
 status - NOT USED

Registered users

=back

=head1 METHODS

=cut

# modes that can be accessed without a valid session
my @free_modes = qw(
	home
	login login_process
	register register_process
	logout
	about faq stats
	posts threads dist users author privacy_policy
	search all
	site_is_closed
	help
	rss
	atom
	tags
	m
	no_such_page
	reset_password_form
	reset_password_form_process
	reset_password_request
	reset_password_request_process
);
my @restricted_modes = qw(
	new_post process_post
	mypan
	admin
	admin_process
	admin_edit_user
	admin_edit_user_process
	add_new_group
	response_form
	module_search
	selfconfig change_password change_info update_subscription
	update
);

my @urls = qw(
	logout
	help
	new_post 
	login register
	posts about stats
	threads dist users author
	response_form
	faq
	admin
	admin_edit_user
	mypan selfconfig privacy_policy
	search all
	rss
	atom
	update
	tags
	reset_password_form
	reset_password_form_process
	reset_password_request
	reset_password_request_process
);


=head2 cgiapp_init

 Connect to database
 Setup logging
 Setup session

=cut

sub cgiapp_init {
	my $self = shift;

	$self->param( 'start_time', time );

	CPAN::Forum::DBI->myinit();
	$STATUS_FILE = $self->param("ROOT") . "/db/status";
	$self->tt_config(
		TEMPLATE_OPTIONS => {
			INCLUDE_PATH => $self->param("ROOT") . "/tt",
			POST_CHOMP   => 1,
			EVAL_PERL    => 0,                # evaluate Perl code blocks
			ENCODING     => 'utf8',
		});

	CGI::Session->name($cookiename);

	return;
}


=head2 setup

Standard CGI::Application method

=cut

sub setup {
	my $self = shift;

	#my $log       = $ENV{CPAN_FORUM_LOGFILE};
	#my $log_level = $self->_set_log_level();

	$self->log_config(
		LOG_DISPATCH_MODULES => [
			{   module            => 'Log::Dispatch::Screen',
				name              => 'messages',
				stderr            => 1,
#				filename          => $log,
#				min_level         => $log_level,
				min_level         => 'notice',
#				mode              => 'append',
				callbacks         => sub { $self->_logger(@_) },
#				close_after_write => 1,
			},
		],
		APPEND_NEWLINE => 1,
	);

	$self->session_config(
		#CGI_SESSION_OPTIONS => [ "driver:File", $self->query, {Directory => "/tmp"}],
		#CGI_SESSION_OPTIONS => [ "driver:SQLite", $self->query, {Handle => $dbh}],
		COOKIE_PARAMS => {
			-expires => '+14d',
			-path    => '/',
		},
		SEND_COOKIE => 0,
	);

	$self->start_mode("home");
	$self->run_modes( [ @free_modes, @restricted_modes ] );
	$self->run_modes( AUTOLOAD => "autoload" );
	$self->error_mode('error');

	return;
}


=head2 cgiapp_prerun

We use it to change the run mode according to the requested URL.
Maybe we should move his code to the mode_param method ?

=cut

sub cgiapp_prerun {
	my $self = shift;

	$self->header_props(
		-charset => "utf-8",
		-type    => 'text/html',
	);
	
	$self->tt_params(
		"dev_server"        => ( $ENV{CPAN_FORUM_DEV} ? 1 : 0 ),
	);

	$self->param( path_parameters => [] );

	my $status = $self->status();
	if ( $status ne "open" and not $self->session->param("admin") ) {
		$self->prerun_mode('site_is_closed');
		return;
	}

	my $rm = $self->_set_run_mode();

	if ( any { $rm eq $_ } @free_modes ) {
		return;
	}

	# Redirect to login, if necessary
	if ( not $self->session->param('loggedin') ) {
		$self->session->param( request => $rm );
		if ( $rm eq 'new_post' ) {
			my $group = ${ $self->param("path_parameters") }[0];
			$self->session->param( request_group => $group );
		}
		$self->prerun_mode('login');
		return;
	}
}

# These cannot be set during cgiapp_prerun as we might be just
# logging in/out and we need to set this after the fact
sub tt_pre_process {
	my ($self, $page, $params) = @_;
	$params ||= {};

	$params->{version}  = time; #$VERSION;
	$params->{loggedin} = $self->session->param("loggedin") || "";
	$params->{username} = $self->session->param("username") || "anonymous";
	$params->{admin}    = $self->session->param('admin');
	$params->{language_hu} = 1;

	return;
}


sub cgiapp_postrun {
	my $self       = shift;
	my $output_ref = shift;

	my $rm = $self->get_current_runmode();
	if ( not $self->session->param('loggedin') and $rm ne "login" ) {
		$self->session->delete();
	}

	# flush added as the Test::WWW::Mechanize::CGI did not work well without
	# it after we started to use file based session objects
	$self->session->flush();

	my $ellapsed_time = time() - $self->param('start_time');

	# first let's try to resolve the really big problems
	if ( $ellapsed_time > 1 ) {
		my $rm = $self->get_current_runmode();
		$self->log->warning("Long request. Ellapsed time: $ellapsed_time on run-mode: $rm");
	}

	return;
}

#sub teardown {
#	my ($self) = @_;
#}



# keys of the hash: level, message, name
sub _logger {
	my ( $self, %h ) = @_;
	my ( $package, $filename, $line, $sub ) = caller(6);
	my $root = $self->param("ROOT");
	my $q    = $self->query;
	$filename =~ s/^$root//;
	return sprintf "[%s] - %s - [$$] [%s] [%s] [%s] [%s(%s)] %s\n",
		POSIX::strftime( "%Y-%m-%d %H:%M:%S", localtime ),
		$h{level},
		( $ENV{REMOTE_ADDR} || '' ),
		( $ENV{HTTP_REFERER} || '' ), $q->script_name . $q->path_info, #($self->param('REQUEST')),
		$filename, $line, $h{message};
}

sub _set_log_level {
	my ($self) = @_;

	if ( open my $fh, '<', $self->param("ROOT") . "/db/log_level" ) {
		chomp( my $str = <$fh> );
		$str =~ s/^\s*|\s*$//g;
		if ( Log::Dispatch->level_is_valid($str) ) {
			return $str;
		} else {
			warn "Invalid log level '$str'\n";
		}
	}
	return 'notice';
}

=head2 config

Given a filed name returns the configuration value from the database

=cut

sub config {
	my ( $self, $field ) = @_;

	CPAN::Forum::DB::Configure->param($field);
}


sub _set_run_mode {
	my ($self) = @_;

	my $rm = $self->get_current_runmode();
	return $rm if $rm and $rm ne 'home'; # alredy has run-mode
	$rm = 'home';                        # set to default ???

	my $q = $self->query;

	# override rm based on REQUEST
	my $request = $q->script_name . $q->path_info; # $self->param('REQUEST');
	if ($request =~ m{^/+
                    ([^/]+)        # first word till after the first /
                    (?:/+(.*))?     # the rest, after the (optional) second /
                    }x
		)
	{
		my $newrm = $1;
		my $params = $2 || "";
		if ( any { $newrm eq $_ } @urls ) {
			my @params = split /\//, $params;
			$self->param( path_parameters => scalar(@params) ? \@params : [] );
			$rm = $newrm;
		} elsif ( $request eq "/cgi/index.pl" ) {

			# this should be ok here
			#$self->log->error("Invalid request: $request}");
		} else {
			$self->log->error("Invalid request: $request");
			$self->prerun_mode('no_such_page');
			return 'no_such_page';
		}
	}
	$self->prerun_mode($rm);
	return $rm;
}

=head2 autoload

Just to avoid real crashes when user types in bad URLs that happen to include 
rm=something

=cut

sub autoload {
	my $self = shift;
	my $rm   = $self->get_current_runmode();
	$self->internal_error();
}

sub no_such_page {
	my $self = shift;
	return $self->notes('no_such_page');
}

=head2 home

This the default run mode, it shows the home page.
Currently aliased to C<all()>;


=cut

sub home {
	all(@_);
}

	# just trying if the languages show up correctly
	#my $languages = CPAN::Forum::DB::Posts->languages();
	#return Dumper $languages;

=head2 all

List the most recent posts.

=cut

sub all {
	my $self = shift;
	my $q    = $self->query;


	my $page = $q->param('page') || 1;
	my $params = $self->_search_results( { where => {}, page => $page } );
	$params ||= {};
	return $self->tt_process('pages/home.tt', $params);
}

=head2 recent_thread

Display the posts of the most recent threads
Not yet working.

=cut

sub recent_threads {
	my ($self) = @_;
	my $q = $self->query;

	my %params;
	return $self->tt_process('pages/home.tt', \%params);
}


=head2 build_listing

Given a reference to an array of Post objects creates and returns
a reference to an array that can be used with HTML::Template to
display the given posts.

=cut

sub build_listing {
	my ( $self, $it ) = @_;

	my @resp;

	# eliminate undefs and duplicates (TODO: I don't know why are there such values)
	my %seen;
	foreach my $p (@$it) {
		next if not defined $p->{thread};
		$seen{ $p->{thread} }++;
	}
	my @threads = keys %seen;

	my $threads = CPAN::Forum::DB::Posts->count_threads(@threads);

	foreach my $post (@$it) {
		#warn "called for each post";
		my $thread = $post->{thread};
		my $thread_count = ( $thread and $threads->{$thread} ) ? $threads->{$thread}{cnt} : 0;
		push @resp, {
			subject      => CPAN::Forum::Tools::_subject_escape( $post->{subject} ),
			id           => $post->{id},
			group        => $post->{group_name},
			thread       => ( $thread_count > 1 ? 1 : 0 ),
			thread_id    => $post->{thread},
			thread_count => $thread_count - 1,

			#date         => POSIX::strftime("%e/%b", localtime $post->{date}),
			#date         => scalar localtime $post->{date},
			seconds    => _ellapsed($post->{seconds}),
			date       => $post->{date},    #_ellapsed($post->{date}),
			postername => $post->{username},
		};
	}
	return \@resp;
}

sub _ellapsed {
	my ($diff)  = @_;
	return 'now' if not $diff;

	my $sec = $diff % 60;
	$diff = ( $diff - $sec ) / 60;
	return sprintf( " %s s ago", $sec ) if not $diff;

	my $min = $diff % 60;
	$diff = ( $diff - $min ) / 60;
	return sprintf( "%s m ago", $min ) if not $diff;

	my $hours = $diff % 24;
	$diff = ( $diff - $hours ) / 24;
	return sprintf( "%s h ago", $hours ) if not $diff;

	return sprintf( "%s d ago", $diff );
}


sub error {
	my ($self) = @_;
	print STDERR $@;
	$self->log->critical($@) if $@;
	$self->internal_error();
}

=head2 internal_error

Gives a custom Internal error page.

Maybe this one should also receive the error message and print it to the log file.

See C<notes()> for simple notes.

=cut

sub internal_error {
	my ( $self, $msg, $tag ) = @_;
	if ($msg) {
		$self->log->warning($msg);
	}
	$tag ||= 'generic';
	my %params = ($tag => 1);
	return $self->tt_process('pages/internal_error.tt', \%params);
}

=head2 notes

Print short notification messages to the user.

=cut

sub notes {
	my ( $self, $msg, %params ) = @_;
	$params{$msg} = 1;
	return $self->tt_process('pages/notes.tt', \%params);
}

=head2 _group_selector


It is supposed to show the form to write a new message but will probably be a 
redirection.

=cut

sub _group_selector {
	my ( $self, $group_name, $group_id ) = @_;
	my $q = $self->query;
	my %group_labels;
	my @group_ids;

	if ($group_id) {
		if ( ref $group_id eq "ARRAY" ) {
			@group_ids = @$group_id;
			@group_labels{@$group_id} = @$group_name;
		} else {
			@group_ids = ($group_id);
			$group_labels{$group_id} = $group_name;
		}
	}

	@group_ids = sort { $group_labels{$a} cmp $group_labels{$b} } @group_ids;

	return $q->popup_menu( -name => "new_group", -values => \@group_ids, -labels => \%group_labels );
}



sub _subscriptions {
	my ( $self, $group ) = @_;

	my $users = CPAN::Forum::DB::Subscriptions->get_subscriptions( 'allposts', $group->{id}, $group->{pauseid} );
	my @usernames = map { { username => $_->{username} } } @$users;

	return { users => \@usernames };
}

sub add_new_group {
	my ($self) = @_;
	if ( not $self->session->param("admin") ) {
		return $self->internal_error( "", "restricted_area" );
	}
	my $q          = $self->query;
	my $group_name = $q->param("group");

	# TODO pausid is currently free text on the form
	# but it has been disabled for now
	# we will have to provide the full list of PAUSEID on the form
	# or check the id from the string
	my $pauseid = $q->param("pauseid");
	if ( $group_name !~ /^[\w-]+$/ ) {
		return $self->notes("invalid_group_name");
	}

	my $group = eval {
		CPAN::Forum::DB::Groups->add(
			name  => $group_name,
			gtype => 3,
		);
	};
	if ($@) {
		return $self->internal_error( "", "failed_to_add_group" );
	}

	my %params = ( updated => 1 );
	return $self->tt_process('pages/admin.tt', \%params);
}


sub status {
	my ( $self, $value ) = @_;

	if ($value) {
		if ( $value eq "open" ) {
			if ( -e $STATUS_FILE ) {
				unlink $STATUS_FILE;

				# TODO check if the file does not exist any more after this action?
			}
			return "open";
		}

		open my $fh, ">", $STATUS_FILE;
		if ( not $fh ) {
			$self->log->warning("Could not open status file '$STATUS_FILE' $!");
			return;
		}
		print $fh $value;
	} else {
		return "open" if not -e $STATUS_FILE;
		open my $fh, "<", $STATUS_FILE;
		my $value = <$fh>;
		chomp $value;
	}

	return $value;
}


sub version {
	return $VERSION;
}


1;

=head1 ACKNOWLEDGEMENTS

Thanks to Offer Kaye for his initial help with HTML and CSS.  Thanks
to Shlomi Fish for some patches. Thanks to all
the people who develop and maintain the underlying technologies.  See
L<http://cpanforum.com/about/> for a list of tools we used.  In addition to
Perl of course.

=head1 DEVELOPMENT

We are using Github for version control:
L<http://github.com/szabgab/CPAN-Forum/>

The list of TODO items are kept in the TODO file in the repository:
L<http://github.com/szabgab/CPAN-Forum/blob/master/TODO>

Discussion of this module will take place on
L<http://cpanforum.com/dist/CPAN-Forum>
If you need help or if you'd like to offer your help.
That's the right place to do it.

=head1 BUGS

Please report them at L<http://rt.cpan.org/>

=head1 LICENSE

Copyright 2004-2010, Gabor Szabo (gabor@pti.co.il)
 
This software is free. It is licensed under the same terms as Perl itself.

=cut

