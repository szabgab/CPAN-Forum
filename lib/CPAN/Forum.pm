package CPAN::Forum;
use strict;
use warnings;

our $VERSION = "0.10";

use base "CGI::Application";
use CGI::Application::Plugin::Session;
use CGI::Application::Plugin::LogDispatch;
use Data::Dumper qw(Dumper);
use Fcntl qw(:flock);
use POSIX qw(strftime);
use Carp qw(cluck carp);
use Mail::Sendmail qw(sendmail);
use CGI ();

use CPAN::Forum::INC;

my $limit       = 20;
my $limit_rss   = 10;
my $cookiename  = "cpanforum";
my $SUBJECT = qr{[\w .:~!@#\$%^&*\()+?><,'";=-]+};

my %errors = (
	"ERR no_less_sign"              => "No < sign in text",
	"ERR line_too_long"             => "Line too long",
	"ERR open_code_without_closing" => "open <code> tag without closing tag",
);


=head1 NAME

CPAN::Forum - Web forum application to discuss CPAN modules

=head1 SYNOPSIS

Visit L<http://www.cpanforum.com/>

=head1 DESCRIPTION

This is a Web forum application specifically designed to be used for
discussing CPAN modules. At one point it might be adapted to be a general
forum software but for now it is released in the hope that people
will help improving it and by that improving the 
L<http://www.cpanforum.com/> site.

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

- /posts/ID  (link to a post)
- /threads/ID  (link to a thread)

=item * We provide RSS feed of the recent posts belonging to any of the groups.

=item * We'll provide search capability with restrictions to groups.

=back

=head1 Authentication

Shared authentication with auth.perl.org? I once tried to do this but then for 
some reason I could not finish the process. Maybe later we'll want to enable 
our users to use their auth.perl.org identity. Maybe we can do it also with 
PerlMonks. Right now we have our own registration and login mechanism.

=head1 INSTALLATION

=head2 Apache

This is the configuration of my Apache server on my notebook

    AddHandler cgi-script .pl

    <VirtualHost 127.0.0.1>
        ServerName cpan.local
        DocumentRoot                /home/gabor/work/gabor/public/dev/CPAN/www/
        ScriptAliasMatch ^/(.*/.*)  /home/gabor/work/gabor/public/dev/CPAN/www/cgi/index.pl/$1
        DirectoryIndex              cgi/index.pl
    </VirtualHost>


    <Directory "/home/gabor/work/dev/CPAN">
        Options Indexes FollowSymLinks ExecCGI
        AllowOverride None
        Order allow,deny
        Allow from 127.0.0.1
    </Directory>

=head2 hosts

For local installations in /etc/hosts I added:

    127.0.0.1         cpan.local

That way, I have a totally separate virtual host just for this application.

In a real setting probably you'll have something like www.cpanforum.com 
pointed to your server.

=head2 Install the perl code

    perl Build.PL
    ./Build
    ./Build test
    ./Build install dir=/path/to/install
    cd /path/to/install

    chmod a+x www/cgi/index.pl  (needed only if you work out of the repository)
    chmod a+x db/forum.db       (or whatever you need to make sure the database is writable by the web server.

Finally, manually edit the www/cgi/index.pl file and set the sha-bang to the 
correct one


=head2 Setup the database

In the directory where you installed the modules create a file called CONFIG 
(see t/CONFIG for an example). Having the following fields:

    username=        The user name of the administrator.
    email=           The E-mail of the administrator.
    password=        The password of the administrator.
    from=            The Email address to be used as the from address in the 
                     messages sent by the system.

You will be able to change all these values later from the web interface but 
we need to have the first values.

Run:

    perl bin/setup.pl 

(you can now delete the CONFIG file)

Run:

    perl bin/populate.pl
    
(this will fetch a file from www.cpan.org and might take a few minutes to run)

=head2 CPAN_FORUM_URL

For some of the tests you'll have to set the CPAN_FORUM_URL environment 
variable to the URL where you installed the forum.

=head2 Changes

v0.09_05
- POD cleanup (Shlomi Fish)

- More tests

- Start using Parse::RecDescent

v0.09_04

- Before writing a new post instead of showing a list of all the modules now 
the user first will search for a module name.  post link should give a search
box that will let the user search within the names of the modules. The result
should be a restricted list with only a few module names in a pull-down menu
like we have now.  The search is a regular SQL LIKE search and we add % signs
at both ends of the typed in word.


=head2 TODO

- Decide on Basic Markup language and how to extend for shortcuts opening tag
for code:  <code[^>]*>  but right now only <code> should be accepted closing
tag for code:  </code>

- check all submitted fields (restrict posting size to 10.000 Kbyte ?
- Make the site look nicer (HTML and css work)
- Improve text and explanations.
- Improve Legal statement, look at other sites.


clean up documentation

add indexes to the tables ?

show the release dates of the various versions of a module so
it is easy to compare that to the post.

Authentication and user management process:
- new user comes to our site we give him a cookie, when he wants to login we offer him
--  login using the auth.perl.org credentials
--  login using XYZ credentials
--  create local credential

-- For auth.perl.org
--- redirect the user to auth.perl.org wait till he logs in there (maybe even creates the new account)
--- sets the preferences
--- comes back
--- we can fetch some of the information from that user
--- we need to keep the user_id received from auth.perl.org for later identification of the user
--- while we tell the user we would like to get the username/fullname/e-mail
address from auth he might not want to give, for this case we should have our
way to update the locally updated username, full name and validated e-mail
address.
  
--- For XYZ we have to see how they work

-- For local credentials we need the user to give us 
username/password/fullname and validated e-mail address.


We have to make sure that usernames which are displayed don't collide. Maybe we
should use separate fields for usernames from various sources and when
displayed we might prefix it auth:gabor, local:gabor etc.  Not nice, any better
way ?

- Add constraint checking to every field that the user can change by submitting
information.  

- Finalize markup

Subject field:
-  <= 50 chars
-  Can contain any characters, we'll escape them when showing on the web site
 
Text field:
- No restriction on line length, let the HTML handle that part
- The text is divided into areas of free text and marked sections

In order to avoid accepting postings today that will break when we add more 
tags, we will reject any submission that is not correctly marked up.

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


- Enable some administrator to mark a message (or a whole thread) to be hidden 
(database already has field)

- Enable some administator to mark a group to be 
- hidden (messages don't show up)
- frozen (cannot add new message but still can see the earlier messages)
Critical part: make place for this in database (status field)

- Administrator (or even the author ?) should be able to move a message from
one module to another module or group.

 
- Enable administrator to ban a user (mark in the users database to disable the user)
Hmm, do I really need this ? maybe as I cannot just delete a user. (added a 
status field that is not used currently)

=head1 TODO Nice to have

- Make sure adding a new module works fine

- make paging available responses 1..10, 11.20, etc, 

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

=head1 TODO Next release only

- make the page size (for paging) user configurable

- Notify user

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


- Fix Installation

- when installing one might need to be root, in order to set the permissions 
correctly ?

- as user www fetch the module list file, unzip it in the db directory (as 
this is the only directory we can write to) and run the populator

- on a new installation, change the ownership of directories (or at leas tell
the user to do so)


- Write comprehensive test suit

- Reply within a thread

When replying to a post within a thread we might want to open the editor window
in the middle of the thread, just below the post I am responding to.

- Make the Session use the database instead of plain file

- Make autoposter of new version announcements work

A script that will send an announcement on the new version of every module to
the list I think this is done as a script listening in the cpan-testers mailing
list, though it might be one similar to bin/populate.pl

- make sure links that are relevant for distros don't show up on pages which
don't belong to distros. (e.g. a link to search.cpan.org/dist/CGI is ok but a
link to search.cpan.org/dist/General is not)

- Sometime we'll want to post a message in more than one group, e.g.  now I'd
like to know how to use CGI::Session with DBD::SQLite. I might want to post the
message on more than one list at the same time as this is related to more than
one module.  Porbably if I need to chose one I'll select CGI::Session as I am
trying to use that but it might be a nice feature.  Maybe I need to tell one
module as the main group and then have a way to associate a few more modules
with the posting.

This can be done by de-coupleing the name of the distribution from the posts table for all the distributions or we can add such an extra table for the additional distributions so there will be a leading distro of the thread.


- Getting the listing of all ~7000 module names takes a long time.
I should profile it.
1) write a small script that will run the relevant code on the command line,
2) time this
3) look at the size of the output 386K -> it won't fly, you can't have such a page
on the web. Other solutions: 
- type in the name
- search for the name
- currently we'll keep a separate file called db/modules.txt with a listing of all
the distros. This make page generation in 1-2 sec instead of 7-8. Obviously
there is a problem we'll have to fix.


- Create a group for 
- each Distribution (DONE)
- Some bigger groups (eg. databases, testing, )
maybe put each distribution under one or more of the groups too
- General and other special purpose groups such as News (for the site)
where only "administrators" can post.

I am not sure if I have to keep all these things in one table and if the
same form has to serve for creating messages in both distros and categories.

- Database or plain files ?

I think every information should be in the database but then we might want to
generate static pages from the posts and discussions in order to reduce the
need to fetch information from the database. Hmm, it sound faster but we'll
probabl want to build the pages on the fly anyway so maybe it does not improve
anything. We can start off by totally dynamic pages and then see if making them
static will reduce the load on the server. First we'll have to have load on the
server. :-) 

- Check if the technique we use to remember the last request before login
cannot cause some security problem such as remembering the last request of
someone else who used the same machine recently ? 

- xml - provided

- favicon.ico and a banner image would be good


Shlomi:
The Forum uses cgiapp_prerun to set the mode according to the PATH_INFO instead of 
using a mode_param code-reference. This causes a lot of warnings in the logs, 
and doesn't really belong in cgiapp_prerun.

It cannot be hosted on a URL except for its own virtual host, as it uses 
absolute URLs. ("/login/", "/register/", etc.) A better idea would be to 
track the path that the web-server gives (it's in one of the environment 
variables) and then to construct a /cpan-forum/login/ /cpan-forum/register/ 
etc. path. (or use relative URLs).



=head1 METHODS

=head2 cgiapp_init

Standard CGI::Application method.

Setup the Session object and the default HTTP headers

=cut

sub cgiapp_init {
	my $self = shift;
	my $dbh = CPAN::Forum::DBI::db_Main();

	$self->log_config(
		LOG_DISPATCH_MODULES => [
		{
			module            => 'Log::Dispatch::File',
			name              => 'messages',
			filename          => '/tmp/messages.log',
			min_level         => 'debug',
			mode              => 'append',
			close_after_write => 1,
		},
#		{
#			module  => 'Log::Dispatch::Email::MailSend',
#			name    => 'email',
#			to      => [ qw(foo@bar.org) ],
#			subject => 'CPAN::Forum: Oh No!!!!!!!!!!',
#			min_level => 'emerg'
#		}
		],
		APPEND_NEWLINE => 1,
	);

	$self->log->debug("--- START ---");

	CGI::Session->name($cookiename);
	$self->session_config(
		CGI_SESSION_OPTIONS => [ "driver:SQLite", $self->query, {Handle => $dbh}],
		COOKIE_PARAMS       => {
				-expires => '+24h',
				-path    => '/',
		},
		SEND_COOKIE         => 1,
	);
	
	$self->header_props( 
		-expires => '-1d',  
		# I think this this -expires causes some strange behaviour in IE 
		# on the other hand it is needed in Opera to make sure it won't cache pages.
		-charset => "utf-8",
	);
	$self->session_cookie();
}

# modes that can be accessed without a valid session
my @free_modes = qw(home 
					pwreminder pwreminder_process 
					login login_process 
					register register_process 
					logout 
					about faq
					posts threads dist users 
					search all 
					help
					rss ); 
my @restricted_modes = qw(
			new_post process_post
			mypan 
			response_form 
			module_search
			selfconfig change_password update_subscription); 
			
my @urls = qw(
	logout 
	help
	new_post pwreminder 
	login register 
	posts about 
	threads dist users 
	response_form 
	faq 
	mypan selfconfig 
	search all rss); 

=head2 setup

Regular CGI::Appication method to setup the list of all run modes and the default run mode 

=cut
sub setup {
	my $self = shift;
	$self->start_mode("home");
	$self->run_modes([@free_modes, @restricted_modes]);
	$self->run_modes(AUTOLOAD => "autoload");
}

=head2 cgiapp_prerun

Regular CGI::Application method

We use it to change the run mode according to the requested URL (PATH_INFO).
Maybe we should move his code to the mode_param method ?

=cut

sub cgiapp_prerun {
	my $self = shift;
	my $rm = $self->get_current_runmode();

	$self->log->debug("Current runmode:  $rm");

	$self->param(path_parameters => []);

	if (not $rm or $rm eq "home") {
		if ($ENV{PATH_INFO} =~ m{^/
								([^/]+)        # first word till after the first /
								(?:/(.*))?     # the rest, after the (optional) second /
								}x) {
			my $newrm = $1;
			my $params = $2 || "";
			if (grep {$newrm eq $_} @urls) {
				my @params = split /\//, $params;
				$self->param(path_parameters => @params ? \@params : []);
				$rm = $newrm;
				$self->prerun_mode($rm);
			} elsif ($ENV{PATH_INFO} eq "/cgi/index.pl") {
				# TODO this is temporary to avoid unnecessary warnings
			} else {
				warn "Invalid PATH_INFO: $ENV{PATH_INFO}";
				# shall I make more noise ? 
			}
		}
		
	}

	$self->log->debug("Current runmode:  $rm");

	return if grep {$rm eq $_} @free_modes;
	#return if not grep {$rm eq $_} @restricted_modes;

	# Redirect to login, if necessary
	if (not  $self->session->param('loggedin') ) {
		$self->session->param(request => $ENV{PATH_INFO});
		$self->header_type("redirect");
		$self->header_props(-url => "http://$ENV{HTTP_HOST}/login/");
		return;
	}
}


=head2 autoload

Just to avoid real crashes when user types in bad URLs that happen to include 
rm=something

=cut

sub autoload {
	my $self = shift;
	$self->internal_error;
}


=head2 home

This the default run mode, it shows the home page that includes the list of
most recent posts.

=cut
sub home {
	my $self = shift;
	
	my $t = $self->load_tmpl("home.tmpl",
		loop_context_vars => 1,
	);
	
	my $from = ${$self->param("path_parameters")}[1] || 0;
	my $cnt  = ${$self->param("path_parameters")}[2] || $limit;
	$t->param(messages => $self->build_listing(
			scalar CPAN::Forum::Posts->retrieve_latest($from+$cnt),
			CPAN::Forum::Posts->count_all(),
			));

	$t->output;
}

sub all {
	home(@_);
}

=head2 build_listing

Receives a CPAN::Forum::Posts iterator and optionally two numbers
Builds an array of hashes from all the posts or those in the given range
and returns the array reference.

=cut

sub build_listing {
	my ($self, $it, $total) = @_;
	$self->log->debug("build_listing: total=$total");
	
	my $from = ${$self->param("path_parameters")}[1] || 0;
	my $cnt  = ${$self->param("path_parameters")}[2] || $limit;
	my $to   = $from+$cnt-1;
	
	my @resp;
	if ($to) {
		$it = $it->slice($from, $to);
	}

	#my $start = $from % $cnt;
	
	
	

	while (my $post = $it->next) {
		#(my $dashgroup = $post->gid) =~ s/::/-/g;
		my $thread_count = CPAN::Forum::Posts->sql_count_thread($post->thread)->select_val;
		push @resp, {
			subject      => _subject_escape($post->subject), 
			id           => $post->id, 
			group        => $post->gid->name, 
			#dashgroup    => $dashgroup,
			thread       => ($thread_count > 1 ? 1 : 0),
			thread_id    => $post->thread,
			thread_count => $thread_count-1,
			#date         => strftime("%e/%b", localtime $post->date),
			date         => scalar localtime $post->date,
			postername   => $post->uid,
			};
	}
	#@resp = reverse @resp if $to; # Otherwise we fetched in DESC order
	return \@resp;
}

=head2 redirect_home

Just to easily redirect to the home page

=cut

sub redirect_home {
	my $self = shift;
	$self->header_type("redirect");
	$self->header_props(-url => "http://$ENV{HTTP_HOST}/");
}

=head2 about

About box with some statistics.

=cut

sub about {
	my $self = shift;
	my $t = $self->load_tmpl("about.tmpl");
	
	$t->param(distro_cnt => CPAN::Forum::Groups->count_all());
	$t->param(posts_cnt  => CPAN::Forum::Posts->count_all());
	$t->param(users_cnt  => CPAN::Forum::Users->count_all());
	$t->param(version    => $VERSION);

	$t->output;
}

sub faq {
	my $self = shift;
	my $t = $self->load_tmpl("faq.tmpl");
	$t->output;
}

=head2 internal_error

Gives a custom Internal error page.

Maybe this one should also receive the error message and print it to the log file.

=cut

sub internal_error {
	my ($self, $msg) = @_;
	cluck $msg if $msg;
	my $t = $self->load_tmpl("internal_error.tmpl");
	$t->output;
}

=head2 load_tmpl

Semi standard CGI::Application method to replace the way we load the templates.

=cut

sub load_tmpl {
	my $self = shift;

	my $t = $self->SUPER::load_tmpl(@_, 
#		      die_on_bad_params => -e ($self->param("ROOT") . "/die_on_bad_param") ? 1 : 0
	);
	$t->param("loggedin" => $self->session->param("loggedin") || "");
	$t->param("username" => $self->session->param("username") || "anonymous");
	$t->param("test_site_warning" => -e $self->param("ROOT") . "/config_test_site");
	return $t;
}
# config_fake_login  (not used currently)


sub login {
	my ($self, $errs) = @_;
	my $q = $self->query;

	my $t = $self->load_tmpl(
			"login.tmpl",
			associate => $q,
	);

	$t->param($errs) if $errs;
	return $t->output;
}

=head2 login_process

- Processing the information provided by the user, 
- calling for authentication
- setting the session

- redirecting to the page where the user wanted to go before he was diverted to the login page

=cut

sub login_process {
	my $self = shift;
	my $q = $self->query;

	if (not $q->param('nickname') or not $q->param('password')) {
		return $self->login({no_login_data => 1});
	}

	my ($user) = CPAN::Forum::Users->search({
					username => $q->param('nickname'),
					password => $q->param('password'),
			});
	if (not $user) {
		return $self->login({bad_login => 1});
	}

	my $session = $self->session;
	$session->param(loggedin  => 1);
	$session->param(username  => $user->username);
	$session->param(uid       => $user->id);
	$session->param(fname     => $user->fname); # TODO
	$session->param(lname     => $user->lname); # TODO
	$session->param(email     => $user->email);

	my $request = $session->param("request") || "";
	$session->param("request" => "");
	$self->header_type("redirect");
	$request .= "/" if $request !~ m{/$};
	$self->header_props(-url => "http://$ENV{HTTP_HOST}/$request");
}


=head2 logout

Set the session to be logged out and remove personal information from the Session object.

=cut

sub logout {
	my $self = shift;
	
	my $session = $self->session;
	$session->param(loggedin => 0);
	$session->param(username => '');

	$self->redirect_home;
}


sub register {
	my $self = shift;
	my $errs = shift;
	my $q = $self->query;

	my $t = $self->load_tmpl(
			"register.tmpl",
			associate => $q,
	);

	$t->param($errs) if $errs;
	return $t->output;
}


sub register_process {
	my ($self) = @_;
	my $q = $self->query;

	if (not $q->param('nickname') or not $q->param('email')) {
		return $self->register({"no_register_data" => 1});
	}
	
	# TODO arbitrary nickname constraint, allow other nicknames ?
	if ($q->param('nickname') !~ /^[a-z0-9]{4,10}$/) {
		return $self->register({"bad_nickname" => 1});
	}

	# TODO fix the e-mail checking and the error message
	if ($q->param('email') !~ /^[a-z0-9_+@.-]+$/) {  
		return $self->register({"bad_email" => 1});
	}
	
	my $user = eval {
		CPAN::Forum::Users->create({
				username => $q->param('nickname'),
				email    => $q->param('email'),
			});
	};
	if ($@) {
		return $self->register({"nickname_exists" => 1});
	}

	$self->send_password($user);
	$self->notify_admin($user);
	return $self->register({"done" => 1});
}

sub send_password {
	my ($self, $user) = @_;

	# TODO: put this text in a template
	my $password = $user->password;
	my $subject = "CPAN::Forum registration";
	my $message = <<MSG;

Thank you for registering on the CPAN::Forum at
http://$ENV{HTTP_HOST}/

your password is: $password


MSG

	my ($field) = CPAN::Forum::Configure->search({field => "from"});
	my $FROM = $field->value;
	$self->log->debug("FROM field set to be $FROM");

	my %mail = (
		To       => $user->email,
		From     => $FROM,
		Subject  => $subject,
		Message  => $message,
	);
	sendmail(%mail);
}

sub notify_admin {
	my ($self, $user) = @_;

	my ($field) = CPAN::Forum::Configure->search({field => "from"});
	my $FROM = $field->value;

	# TODO: the admin should be able to configure if she wants to get messages on
	# every new user (field update_on_new_user)
	my $admin = CPAN::Forum::Users->retrieve(1);
	my %mail = (
		To      => $admin->email,
		From     => $FROM,
		Subject => "New Forum user: " . $user->username,
		Message => "\nUsername: " . $user->username . "\n",
	);
	sendmail(%mail);
}

sub pwreminder {
	my ($self, $errs) = @_;
	my $q = $self->query;

	my $t = $self->load_tmpl(
			"pwreminder.tmpl",
			associate => $q,
	);

	$t->param($errs) if $errs;
	return $t->output;
}


sub pwreminder_process {
	my ($self) = @_;
	my $q = $self->query;
	if (not $q->param('nickname') and not $q->param('email')) {
		return $self->pwreminder({"no_data" => 1});
	}

	my $user;
	if ($q->param('nickname')) {
		($user) = CPAN::Forum::Users->search({username => $q->param('nickname')});
	} else {
		($user) = CPAN::Forum::Users->search({email    => $q->param('email')});
	};
	return $self->pwreminder({"no_data" => 1}) if not $user;

	# TODO: put this text in a template
	my $password = $user->password;
	my $subject = "CPAN::Forum password reminder";
	my $message = <<MSG;


Your password on the CPAN::Forum is: $password
Use it wisely.

http://$ENV{HTTP_HOST}/


MSG

	my ($field) = CPAN::Forum::Configure->search({field => "from"});
	my $FROM = $field->value;
	$self->log->debug("FROM field set to be $FROM");

	my %mail = (
		To       => $user->email,
		From     => $FROM,
		Subject  => $subject,
		Message  => $message,
	);
	sendmail(%mail);

	return $self->pwreminder({"done" => 1});
}


=head2 _group_selector


It is supposed to show the form to write a new message but will probably be a 
redirection.

=cut

sub _group_selector {
	my ($self, $group_name, $group_id) = @_;
	my $q = $self->query;

	my %group_labels;
	my @group_ids;
	
	if ($group_id) {
		if (ref $group_id eq "ARRAY") {
			@group_ids = @$group_id;
			@group_labels{@$group_id} = @$group_name;
		} else {
			@group_ids = ($group_id);
			$group_labels{$group_id} = $group_name;
		}
	}


	my $cache = $self->param("ROOT") . "/db/modules.txt";
	if (not @group_ids and open my $fh, $cache) {
		foreach my $line (<$fh>) {
			chomp $line;
			my ($id, $name) = split /:/, $line, 2;
			push @group_ids, $id;
			$group_labels{$id} = $name;
		}
	}

	if (not @group_ids) {
		my @groups = CPAN::Forum::Groups->search(gtype => $CPAN::Forum::DBI::group_types{Distribution});
		foreach my $g (@groups) {
			push @group_ids, $g->id;
			$group_labels{$g->id} = $g->name;
		}

#		@groups = (
#		"Global", 
#		"----",
#		(sort map {$_->name} CPAN::Forum::Groups->search(gtype => $CPAN::Forum::DBI::group_types{Fields})),
#		"----",
#			(sort map {$_->name} CPAN::Forum::Groups->search(gtype => $CPAN::Forum::DBI::group_types{Distribution})),
#		);
	}
	@group_ids = sort {$group_labels{$a} cmp $group_labels{$b}}  @group_ids;
	
	return $q->popup_menu(-name => "new_group", -values => \@group_ids, -labels => \%group_labels);
}



sub new_post {
	posts(@_);
}


=head2 response_form

Probably obsolete.

=cut

sub response_form {
	posts(@_);
}


sub module_serach_form {
	my ($self, $errors) = @_;
	my $t = $self->load_tmpl("module_search_form.tmpl");
	$t->param($_=>1) foreach @$errors;
	$t->output;
}

=head2 posts

Show a post, the editor and a preview - whichever is needed.

=cut

sub posts {
	my ($self, $errors) = @_;
	my $q = $self->query;

	my $t = $self->load_tmpl(
			"posts.tmpl",
			associate => $q,
	);
	$t->param($_=>1) foreach @$errors;

	my $rm = $self->get_current_runmode();
	$self->log->debug("posts rm=$rm");

	my $new_group = "";
	my $new_group_id;
	
	if ($rm eq "new_post") {
		$new_group = ${$self->param("path_parameters")}[0] || "";
		$new_group_id = $q->param('new_group') if $q->param('new_group');
		
		if ($new_group) {
			if ($new_group =~ /^([\w-]+)$/) {
				$new_group = $1;
				my ($gr) = CPAN::Forum::Groups->search(name => $new_group);
				if ($gr) {
					$new_group_id = $gr->id;
				} else {
					cluck "Group '$new_group' was not in database when accessed PATH_INFO: '$ENV{PATH_INFO}'";
					return $self->internal_error;
				}
			} else {
				cluck "Bad regex for '$new_group' ? Accessed PATH_INFO: '$ENV{PATH_INFO}'";
				return $self->internal_error;
			}
		} elsif ($new_group_id) {
			my ($gr) = CPAN::Forum::Groups->retrieve($new_group_id);
			if ($gr) {
				$new_group = $gr->name;
			} else {
				cluck "Group '$new_group_id' was not in database when accessed PATH_INFO: '$ENV{PATH_INFO}'";
				return $self->internal_error;
			}
		} elsif ($q->param('q')) {
			# process search later	
		} else {
			# TODO should be called whent the module_search is ready
			return $self->module_serach_form();
		}
	}
	if ($rm eq "process_post") {
		$new_group_id = $q->param("new_group");
		return $self->internal_error(
			"Missing new_group_id. Accessed PATH_INFO: '$ENV{PATH_INFO}'")
			if not $new_group_id;

		if ($new_group_id =~ /^(\d+)$/) {
			$new_group_id = $1;
			my ($grp) = CPAN::Forum::Groups->retrieve($new_group_id);
			if ($grp) {
				$new_group = $grp->name;
			} else {
				return $self->internal_error("Bad value for new_group (id) '$new_group_id' ? Accessed PATH_INFO: '$ENV{PATH_INFO}'");
			} 
		} else {
			return $self->internal_error("Bad value for new_group (id) '$new_group_id' ? Accessed PATH_INFO: '$ENV{PATH_INFO}'");
		}
	}
	#warn $new_group;
	#warn $new_group_id;

	#$new_group =~ s/-/::/g;
	#(my $dashgroup = $new_group) =~ s/::/-/g;
	#$t->param(dashgroup => $dashgroup);

	my $title = ""; # of the page
	my $editor = 0;
	$t->param(editor    => 1) if grep {$rm eq $_} (qw(process_post new_post response_form));

	
	my $id = $q->param("id");  # there was an id 
	if ($rm eq "response_form" or $rm eq "posts") {
		$id = ${$self->param("path_parameters")}[0] if ${$self->param("path_parameters")}[0];
	}
	$id ||= $q->param("new_parent");
	if ($id) { # Show post
		my $post = CPAN::Forum::Posts->retrieve($id);
		if (not $post) {
			cluck "PATH_INFO: $ENV{PATH_INFO}";
			return $self->internal_error;
		}
		my $thread_count = CPAN::Forum::Posts->sql_count_thread($post->thread)->select_val;
		if ($thread_count > 1) {
			$t->param(thread_id    => $post->thread);
			$t->param(thread_count => $thread_count);
		}
		my %post = %{$self->_post($post)};
		$t->param(%post);
		
#		(my $dashgroup = $post->gid) =~ s/::/-/g;
#		$t->param(dashgroup    => $dashgroup);
		my $new_subject = $post->subject;
		if ($new_subject !~ /^\s*re:\s*/i) {
			$new_subject = "Re: $new_subject";
		}
		
		$t->param(new_subject  => _subject_escape($new_subject));
		$t->param(title        => _subject_escape($post->subject));
		$t->param(post         => 1);
		
		$new_group        = $post->gid->name;
		$new_group_id     = $post->gid->id;   	
	}
	$t->param("group_selector" => $self->_group_selector($new_group, $new_group_id));
	
	# for previewing purposes:
	# This is funky, in order to use the same template for regular show of a message and for
	# the preview facility we create a loop around this code for the preview page (with hopefully
	# only one iteration in it) The following hash is in preparation of this internal loop.
	if (not @$errors or $$errors[0] eq "preview") {
		my %preview;
		$preview{subject}    = _subject_escape($q->param("new_subject")) || "";
		$preview{text}       = _text_escape($q->param("new_text"))    || "";
		$preview{parentid}   = $q->param("new_parent")  || "";
#		$preview{thread_id}  = $q->param("new_text")    || "";
		$preview{postername} = $self->session->param("username");
		$preview{date}       = _post_date(time);
		$preview{id}         = "TBD";

		$t->param(preview_loop => [\%preview]);
	}

	#$t->param(new_subject => _subject_escape($q->param("new_subject")));
	$t->param(group       => $new_group) if $new_group;

	return $t->output;
}


=head2 process_post

Process a posting, that is take the values from the CGI object, check if they
are acceptable and try to add them to the database. If anything bad happens,
give an error message preferably by filling out the form again.

=cut

sub process_post {
	my $self = shift;
	my $q = $self->query;
	my @errors;
	my $parent = $q->param("new_parent");
	
	my $parent_post;
	if ($parent) { # assume response
		($parent_post) = CPAN::Forum::Posts->search(id => $parent);
		push @errors, "bad_thing"  if not $parent_post;
	} else {       # assume new post
		if ($q->param("new_group")) {
			push @errors, "bad_group"  if not CPAN::Forum::Groups->search(id => $q->param("new_group"));
		} else {
			push @errors, "no_group";
		}
	}
	
	my $new_subject = $q->param("new_subject");
	my $new_text = $q->param("new_text"); 
	
	push @errors, "no_subject" if not $new_subject;
	push @errors, "invalid_subject" if $new_subject and $new_subject !~ m{^$SUBJECT$};
	
	push @errors, "no_text"    if not $new_text;
	push @errors, "subject_too_long" if $new_subject and length($new_subject) > 50;
	return $self->posts(\@errors) if @errors;
	

	# There will be two buttons, one for Submit and one for Preview.
	# We will save the message only if the Submit button was pressed.
	# When the editor first displayed and every time if an error was caught this button will be hidden.

	my $markup = CPAN::Forum::Markup->new();
	my $result = $markup->posting_process($new_text) ;
	if (not defined $result) {
		$self->log->debug("--- BAD TEXT STARTS ---");
		$self->log->debug($new_text);
		$self->log->debug("--- BAD TEXT ENDS ---");
		push @errors, "text_format";
		return $self->posts(\@errors);
	}


	my $button = $q->param("button");
	if ($button eq "Preview") {
		return $self->posts(["preview"]);
	}
	if ($button ne "Submit") {
		warn "Someone sent in a button called '$button'";
		return $self->internal_error;
	}

	my $pid;
	eval {
		my $post = CPAN::Forum::Posts->create({
			uid     => $self->session->param("username"),
			gid     => $parent_post ? $parent_post->gid : $q->param("new_group"),
			subject => $q->param("new_subject"),
			text    => $new_text,
			date    => time,
		});
		$post->thread($parent_post ? $parent_post->thread : $post->id);
		$post->parent($parent) if $parent_post;
		$post->update;
		$pid = $post->id;
		#warn $parent_post ? $parent_post->gid : $q->param("new_group");
		#warn "PG:" . $post->gid;
	};
	if ($@) {
		#push @errors, "subject_too_long" if $@ =~ /subject_too_long/;
		#warn $CPAN::Forum::Post::lasterror if $@ =~ /text_format/;
		if (not @errors) {
			warn "UNKNOWN_ERROR: $@";
			cluck "PATH_INFO: $ENV{PATH_INFO}";
			return $self->internal_error;
		}
		return $self->posts(\@errors);
	}
	
	$self->notify($pid);

	$self->redirect_home;
}


sub _post_date {
	return scalar localtime $_[0];
}

sub _post {
	my ($self, $post) = @_;
	my @responses = map {{id => $_->id}} CPAN::Forum::Posts->search(parent => $post->id);

	my %post = (
		postername  => $post->uid,
		date        => _post_date($post->date),
		parentid    => $post->parent,
		responses   => \@responses,
		text        => _text_escape($post->text),
	);

	$post{$_} = $post->get($_) for qw(subject id);

	return \%post;
}

sub _subject_escape {
	my ($subject) = @_;
	return CGI::escapeHTML($subject);
}

# this is not correct, the Internal error should be raised all the way up, not as the
# text field...
sub _text_escape {
	my ($text) = @_;

	return "" if not $text;
	my $markup = CPAN::Forum::Markup->new();
	my $html = $markup->posting_process($text);
	if (not defined $html) {
		warn "Error displaying already accepted text: '$text'";
		return "Internal Error";
	}
	return $html;
	#$text =~ s{<}{&lt;}g;
	#$text =~ s{\b(http://.*?)(\s|$)}{<a href="$1">$1</a>$2}g; # urls
	#$text =~ s{mailto:(.*?)(\s|$)}{<a href="mailto:$1">$1</a>$2}g; # e-mail addresses
	#return $text;
}


=head2 threads

Show all the posts of a thread.

=cut

sub threads {
	my $self = shift;

	my $q = $self->query;
	my $t = $self->load_tmpl(
			"threads.tmpl",
			loop_context_vars => 1,
	);
	
	my $id = $q->param("id");
	$id = ${$self->param("path_parameters")}[0] if ${$self->param("path_parameters")}[0];

	my @posts = CPAN::Forum::Posts->search(thread => $id);
	if (not @posts) {
		cluck "PATH_INFO: $ENV{PATH_INFO}";
		return $self->internal_error;
	}

	my @posts_html;
	foreach my $p (@posts) {
		push @posts_html, $self->_post($p);
	}
	$t->param(posts => \@posts_html);
	
#	(my $dashgroup = $posts[0]->gid) =~ s/::/-/g;
	$t->param(group => $posts[0]->gid->name);
#	$t->param(dashgroup => $dashgroup);
	$t->param(title => _subject_escape($posts[0]->subject));

	return $t->output;
}

=head2 dist

List last few posts belonging to this group, provides a link to post a new 
message within this group

=cut

sub dist {
	my $self = shift;
	
	my $q = $self->query;

	my $group = ${$self->param("path_parameters")}[0];
#	$group =~ s/-/::/g;
#	(my $dashgroup = $group) =~ s/::/-/g;


	my $t = $self->load_tmpl("groups.tmpl",
		loop_context_vars => 1,
	);
				
#	$t->param(dashgroup => $dashgroup);
	$t->param(group => $group);
	$t->param(title => "CPAN Forum - $group");

	if ($group =~ /^([\w-]+)$/) {
		$group = $1;
	} else {
		warn "Probably bad regex when checking group name for $group called in $ENV{PATH_INFO}";
		return $self->internal_error();
	}

	my ($gr) = CPAN::Forum::Groups->search(name => $group);
	if (not $gr) {
		warn "Invalid group $group called in $ENV{PATH_INFO}";
		return $self->internal_error();
	}
	my $gid = $gr->id;
	if ($gid =~ /^(\d+)$/) {
		$gid = $1;
	} else {
		warn "Invalid gid received $gid called in $ENV{PATH_INFO}";
		return $self->internal_error();
	}


	$t->param(messages => $self->build_listing(
			scalar CPAN::Forum::Posts->search(gid => $gid, {order_by => 'date DESC'}),
			CPAN::Forum::Posts->sql_count_where("gid", $gid)->select_val,
			));

	$t->output;

}

=head2 users

List the posts of a particular user.

=cut

sub users {
	my $self = shift;
	
	my $q = $self->query;

	my $username="";
	$username = ${$self->param("path_parameters")}[0];

	if (not $username) {
		cluck "No username: PATH_INFO: $ENV{PATH_INFO}";
		return $self->internal_error;
	}

	my $t = $self->load_tmpl("users.tmpl",
		loop_context_vars => 1,
	);
				

	my ($user) = CPAN::Forum::Users->search(username => $username);

	if (not $user) {
		warn "Non existing user was accessed: $ENV{PATH_INFO}";
		return $self->internal_error;
	}


	my $fullname = "";
	$fullname .= $user->fname if $user->fname;
	$fullname .= " " if $fullname;
	$fullname .= $user->lname if $user->lname;
	$fullname = $username if not $fullname;

	$t->param(this_username => $username);
	$t->param(this_fullname => $fullname);
	$t->param(title => "Information about $username");

	$t->param(messages => $self->build_listing(
			scalar CPAN::Forum::Posts->search(uid => $username, {order_by => 'date DESC'}),
			CPAN::Forum::Posts->sql_count_where("uid", $username)->select_val,
			));
	$t->output;
}

sub selfconfig {
	my ($self, $errs) = @_;
	my $t = $self->load_tmpl("change_password.tmpl");
	$t->param($errs) if $errs;
	$t->output;
}

sub change_password {
	my ($self) = @_;
	my $q = $self->query;

	if (not $q->param('password') or not $q->param('pw') or ($q->param('password') ne $q->param('pw'))) {
		return $self->selfconfig({bad_pw_pair => 1});
	}
	
	my ($user) = CPAN::Forum::Users->retrieve($self->session->param('uid'));
	$user->password($q->param('password'));
	$user->update;

	return $self->selfconfig({done => 1});

}

=head2 mypan

Planned to be the manager for the notify subscription, currently not in use.

=cut

sub mypan {
	my $self = shift;

	my $t = $self->load_tmpl("mypan.tmpl",
		loop_context_vars => 1,
	);
	my $username = $self->session->param("username");
	my ($user) = CPAN::Forum::Users->search(username => $username);

	if (not $user) {
		warn "Trouble accessing personal information of: '$username' $ENV{PATH_INFO}";
		return $self->internal_error;
	}
	my $fullname = "";
	$fullname .= $user->fname if $user->fname;
	$fullname .= " " if $fullname;
	$fullname .= $user->lname if $user->lname;
	$fullname = $username if not $fullname;


	$t->param(fullname => $fullname);
#	$t->param(all_post => $user->all_post);
#	$t->param(all_start => $user->all_start);
	$t->param(title => "Information about $username");

	my @params = @{$self->param("path_parameters")};
	my @subscriptions;
	my $gids;


	if (@params == 2 and $params[0] eq "dist") { # specific distribution
		my $group = $params[1];
		my ($grp) = CPAN::Forum::Groups->search(name => $group);
		if (not $grp) {
			warn "Accessing $ENV{PATH_INFO}\n";
			return $self->internal_error;
		}
		$gids = $grp->id;
		my ($s) = CPAN::Forum::Subscriptions->search(uid => $user->id, gid => $grp->id);
		if ($s) {
			push @subscriptions, {
				gid       => $grp->id,
				group     => $group,
				allposts  => $s->allposts,
				starters  => $s->starters,
				followups => $s->followups,
			};
				
		} else {
			push @subscriptions, {
				gid       => $grp->id,
				group     => $group,
				allposts  => 0,
				starters  => 0,
				followups => 0,
			};
		}
	} else { # show all subscriptions
		my $it = CPAN::Forum::Subscriptions->search(uid => $user->id);
		while (my $s = $it->next) {
			#warn $s->allposts;
			$gids .= ($gids ? "," : "") . $s->gid->id; 
			push @subscriptions, {
				gid       => $s->gid,
				group     => $s->gid->name,
				allposts  => $s->allposts,
				starters  => $s->starters,
				followups => $s->followups,
			}
		}
	}
	#warn Dumper \@subscriptions;

	$t->param(subscriptions => \@subscriptions);
	$t->param(gids => $gids);

	$t->output;
}

sub update_subscription {
	my $self = shift;
	my $q = $self->query;
	
	#warn $q->param("gids");
	my @gids = split /,/, $q->param("gids");
	if (not @gids) {
		return $self->internal_error;
	}

	my $username = $self->session->param("username");
	my ($user) = CPAN::Forum::Users->search(username => $username);


	#warn Dumper $q->Vars;
	foreach my $gid (@gids) {
		my ($s) = CPAN::Forum::Subscriptions->search(gid => $gid, uid => $user->id);
		if (not $s) {
			$s = CPAN::Forum::Subscriptions->create({
				uid       => $user->id,
				gid       => $gid,
			});
		}
		my $on=0;
		foreach my $type (qw(allposts starters followups)) {
			if (defined $q->param($type ."_$gid") and $q->param($type . "_$gid") eq "on") {
				$s->set($type, 1);
				$on++;
			} else {
				$s->set($type, 0);
			}
		}
		$s->update;
		$s->delete if not $on;  # remove the whole line if there are no subscriptions at all.
	}


 	$self->notes("mypanok");
}

sub notes {
	my ($self, $msg) = @_;
	my $t = $self->load_tmpl("notes.tmpl");
	$t->param($msg => 1);
	$t->output;
}


# partially written code to select a module name
sub module_search {
	my ($self) = @_;

	my $q = $self->query;
	my $txt = $q->param("q");

	# remove taint if there is
	if ($txt =~ /^([\w:.%-]+)$/) {
		$txt = $1;
	} else {
		$self->log->debug("Tained search: $txt");
	}

	if (not $txt) {
		return $self->module_serach_form(['invalid_search_term']);
	}
	$self->log->debug("group name search term: $txt");
	$txt = '%' . $txt . '%';
	
	my $it =  CPAN::Forum::Groups->search_like(name => $txt);
	my $cnt = CPAN::Forum::Groups->sql_count_like("name", $txt)->select_val;
	my @group_names;
	my @group_ids;
	while (my $group  = $it->next) {
		push @group_names, $group->name;
		push @group_ids, $group->id;
	}
	if (not @group_names) {
		return $self->module_serach_form(['no_module_found']);
	}
	
	#$self->log->debug("GROUP NAMES: @group_names");

	my $t = $self->load_tmpl("module_select_form.tmpl",
	);
	$t->param("group_selector" => $self->_group_selector(\@group_names, \@group_ids));
	$t->output;
}

=head2 search

Search form and processor.

=cut

sub search {
	my $self = shift;

	my $q = $self->query;
	my $txt = $q->param("q");
	
	my $t = $self->load_tmpl("search.tmpl",
		associate => $q,
		loop_context_vars => 1,
	);

	# kill the taint checking (why do I use taint checking if I kill it then ?)
	if ($txt =~ /(.*)/) {
		$txt = $1;
	}

	if ($txt) {
		my $it =  CPAN::Forum::Posts->search_like(text => '%' . $txt . '%');
		my $cnt = CPAN::Forum::Posts->sql_count_like("text", '%' . $txt . '%')->select_val;
		$t->param(messages => $self->build_listing($it,$cnt));
	}

	$t->output;
}

=head2 rss

Provide RSS feed
/rss  latest 20 entries
/rss/dist/Distro-Name  latest 20 entries of that distro name

=cut

sub rss {
	my $self = shift;
	
	my $cnt = $limit_rss;
	my @params = @{$self->param("path_parameters")};
#	warn Dumper \@params;
	my $it;
	if (@params > 1 and $params[0] eq "dist") {
		my $dist = $params[1];
		$it = CPAN::Forum::Posts->search(gid => $dist, {order_by => 'date DESC'}),
	} else {
		$it = CPAN::Forum::Posts->retrieve_latest($cnt);
	}

	require XML::RSS::SimpleGen;
	my $url = "http://$ENV{HTTP_HOST}/";
	my $rss = XML::RSS::SimpleGen->new( $url, "CPAN Forum", "Discussing Perl CPAN modules");
	$rss->language( 'en' );

	my $admin = CPAN::Forum::Users->retrieve(1);
	$rss->webmaster($admin->email);

	my $prefix = "";
	while (my $post = $it->next() and $cnt--) {
		$rss->item($url. "posts/" . $post->id(), $prefix . $post->subject); # TODO _subject_escape ?
	}
#	$rss->save("file.rss");

	
	#print "Content-type: application/xml\n\n", rss_as_string();
	#$self->header_props(-type => 'application/xml');
	
	return $rss->as_string();
	#$self->internal_error;
}

=head2 notify

Send out e-mails upon receiving a submission.

=cut

sub notify {
	my $self = shift;
	my $post_id = shift;
	
	my $post = CPAN::Forum::Posts->retrieve($post_id);

	#	Subject  => '[CPAN Forum] ' . $post->subject,
	my $message = 
		_text2mail ($post->text) .
		"\n\n" .
		"To write a respons, access\n".
		"http://$ENV{HTTP_HOST}/response_form/" . $post->id .
		"\n\n" .
		"To see the full thread, access\n" .
		"http://$ENV{HTTP_HOST}/threads/" . $post->thread .
		"\n\n" .
		"--\n" .
		"You are getting this messages from $ENV{HTTP_HOST}\n" .
		"To change your subscription information visit http://$ENV{HTTP_HOST}/mypan/\n";
	# disclaimer ?
	# X-lits: field ?

	my $subject = sprintf ("[%s] %s",  $post->gid->name, $post->subject); # TODO _subject_escape ?

	my ($field) = CPAN::Forum::Configure->search({field => "from"});
	my $FROM = $field->value;
	$self->log->debug("FROM field set to be $FROM");
	my $admin = CPAN::Forum::Users->retrieve(1);
	# send all messages to Admin, this shuld be configurabele
	my %mail = (
		To       => $admin->email,
		From     => $FROM,
		Subject  => $subject,
		Message  => $message,
	);
	sendmail(%mail);



	my %to;
	# subscriptions to "all" messages in the current group
	#warn $post->gid;
	#warn $post->uid->id;
	my $it = CPAN::Forum::Subscriptions->search(allposts => 1, gid => $post->gid);
	#warn $it;
	_sendmail($it, \%mail, \%to);

	# subscription to thread "starters" in the current group
	if ($post->thread == $post->id) { 
		my $it = CPAN::Forum::Subscriptions->search(starters => 1, gid => $post->gid->id);
		_sendmail($it, \%mail, \%to);
	} else {
		my %ids;
		my $pit = CPAN::Forum::Posts->search(thread => $post->thread);
		while (my $p = $pit->next) {
			$ids{$p->uid}=1;
		}
		
		my $it = CPAN::Forum::Subscriptions->search(followups => 1, gid => $post->gid->id);
		_sendmail($it, \%mail, \%to, \%ids);
		# uid => is one of the uids in the current thread.
		
	}

	# subscriptions 
}

sub _sendmail {
	my ($it, $mail, $to, $ids) = @_;
	
	while (my $s = $it->next) {
		my $email = $s->uid->email;
		$mail->{To} = $email;
		#warn "Sending ? to $email\n";
		next if $ids and not $ids->{$s->uid};
		next if $_[2]->{$email}++;
		#warn "Yes, Sending to $email\n";
		sendmail(%$mail);
	}
}

=head2 _text2mail

replace the markup used in the posting by things we can use in 
e-mail messages.

=cut

sub _text2mail {
	return $_[0];
}


sub help {
	$_[0]->load_tmpl("help.tmpl")->output;
}

1;

=head1 ACKNOWLEDGEMENTS

Thanks to Offer Kaye for his initial help with HTML and CSS.  Thanks to all
the people who develop and maintain the underlying technologies.  See
L<http://www.cpanforum.com/about/> for a list of tools we used.  In addition to
Perl of course.

=head1 DEVELOPMENT

Subversion repository is at 
L<http://svn.pti.co.il/svn/cpan-forum/trunk/>

There is a mailing list to see the commits to the repository:
L<http://perl.org.il/mailman/listinfo/cpan-forum-commit>

Discussion of this module will take place on
L<http://www.cpanforum.com/dist/CPAN-Forum>
If you need help or if you'd like to offer your help.
That's the right place to do it.

=head1 BUGS

Please report them at L<http://rt.cpan.org/>

=head1 LICENSE

Copyright 2004-2005, Gabor Szabo (gabor@pti.co.il)
 
This software is free. It is licensed under the same terms as Perl itself.

=cut

