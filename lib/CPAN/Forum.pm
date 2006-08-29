package CPAN::Forum;
use strict;
use warnings;

our $VERSION = '0.12';

use base 'CGI::Application';
use CGI::Application::Plugin::Session;
use CGI::Application::Plugin::LogDispatch;
use Data::Dumper qw(Dumper);
#use Fcntl qw(:flock);
use POSIX qw(strftime);
#use Carp qw(cluck carp);
use Mail::Sendmail qw(sendmail);
use CGI ();
use List::MoreUtils qw(any);

use CPAN::Forum::INC;
use CPAN::Forum::DBI;

my $cookiename  = "cpanforum";
my $SUBJECT = qr{[\w .:~!@#\$%^&*\()+?><,'";=-]+};
my $STATUS_FILE;

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


=head2 TODO

See the TODO file


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

=head2 TEMPLATES


root templates:

stats.tmpl
about.tmpl
change_password.tmpl
faq.tmpl
groups.tmpl
help.tmpl
home.tmpl
internal_error.tmpl
login.tmpl
module_search_form.tmpl
module_select_form.tmpl
mypan.tmpl
notes.tmpl
posts.tmpl
pwreminder.tmpl
search.tmpl
users.tmpl
register.tmpl
threads.tmpl


every root template should INCLUDE      -> head.tmpl navigation.tmpl footer.tmpl

groups.tmpl            -> links.tmpl listing.tmpl     (list of messages within one group)
home.tmpl              -> listing.tmpl                (list of messages in all the site)
posts.tmpl             -> links.tmpl message.tmpl message.tmpl editor.tmpl  
                                                      (single message 
                                                      with or without the editor
                                                      with or without a preview pane)
search.tmpl            -> listing.tmpl                (list of messages resulted from search)
threads.tmpl           -> links.tmpl
users.tmpl             -> listing.tmpl                (list of messages of one user)


Non root templates:
links.tmpl      - a bunch of links to search.cpan.org and similar places (specific to one distro)
listing.tmpl    - can show the titles of many messages 
message.tmpl    - can show one message (or a preview message)
naviagtion.tmpl -
head.tmpl       -
footer.tmpl     -

Use this for mapping:
grep INCLUDE *| grep -v navigation.tmpl | grep -v footer.tmpl | grep -v head.tmpl

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

=head2 cgiapp_init

 Connect to database
 Setup logging
 Setup session

=cut

sub cgiapp_init {
    my $self = shift;
    
    my $db_connect = $self->param("DB_CONNECT");
    CPAN::Forum::DBI->myinit($db_connect);
    my $dbh = CPAN::Forum::DBI::db_Main();
    
    my $log       = $self->param("ROOT") . "/db/messages.log";
    $STATUS_FILE  = $self->param("ROOT") . "/db/status";
    my $log_level = $self->_set_log_level();

    $self->log_config(
        LOG_DISPATCH_MODULES => [
        {
            module            => 'Log::Dispatch::File',
            name              => 'messages',
            filename          => $log,
            min_level         => $log_level,
            mode              => 'append',
            callbacks         => sub { $self->_logger(@_)},
            close_after_write => 1,
        },
        ],
        APPEND_NEWLINE => 1,
    );

    $self->log->debug("--- START ---");
    

    $self->log->debug("Cookie received: "  . ($self->query->cookie($cookiename) || "") );
    CGI::Session->name($cookiename);
    $self->session_config(
        #CGI_SESSION_OPTIONS => [ "driver:File", $self->query, {Directory => "/tmp"}],
        #CGI_SESSION_OPTIONS => [ "driver:SQLite", $self->query, {Handle => $dbh}],
        COOKIE_PARAMS       => {
                -expires => '+14d',
                -path    => '/',
        },
        SEND_COOKIE         => 0,

    );
    $self->log->debug("sid:  " . ($self->session->id() || ""));
    
    $self->header_props(
        -charset => "utf-8",
    );
}

sub _logger {
    my ($self, %h) = @_;
    return sprintf "[%s] - %s - [%s] [%s] %s\n",
            scalar(localtime), 
            $h{level}, 
            ($ENV{REMOTE_ADDR} || ''),
            ($ENV{HTTP_REFERER} || ''),
            $h{message};
            # keys of the hash: level, message, name
}

sub _set_log_level {
    my ($self) = @_;

    if (open my $fh, '<', $self->param("ROOT") . "/db/log_level") {
        chomp (my $str = <$fh>);
        $str =~ s/^\s*|\s*$//g;
        if (Log::Dispatch->level_is_valid($str)) {
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
    my ($self, $field) = @_;
    
    CPAN::Forum::Configure->param($field);
}

# modes that can be accessed without a valid session
my @free_modes = qw(
    home 
    pwreminder pwreminder_process 
    login login_process 
    register register_process 
    logout 
    about faq stats
    posts threads dist users 
    search all 
    site_is_closed
    help
    rss ); 
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
    selfconfig change_password change_info update_subscription); 
            
my @urls = qw(
    logout 
    help
    new_post pwreminder 
    login register 
    posts about stats
    threads dist users 
    response_form 
    faq 
    admin
    admin_edit_user
    mypan selfconfig 
    search all rss); 

=head2 setup

Standard CGI::Application method

=cut

sub setup {
    my $self = shift;
    $self->start_mode("home");
    $self->run_modes([@free_modes, @restricted_modes]);
    $self->run_modes(AUTOLOAD => "autoload");
}

=head2 cgiapp_prerun

We use it to change the run mode according to the requested URL (PATH_INFO).
Maybe we should move his code to the mode_param method ?

=cut

sub cgiapp_prerun {
    my $self = shift;

    $self->error_mode('error');

    my $status = $self->status();
    $self->log->debug("Status:  $status"); 
    if ($status ne "open" and not $self->session->param("admin")) {
        $self->log->debug('site_is_closed');
        $self->prerun_mode('site_is_closed');
        return; 
    }

    my $rm = $self->_set_run_mode();
    $self->log->debug("Current runmode:  $rm");

    $self->log->debug("Current user:  " . ($self->session->param("username") || ""));
    $self->log->debug("Current sid:  " . ($self->session->id() || ""));

    if (any {$rm eq $_} @free_modes) {
        $self->log->debug('Free mode');
        return;
    }

    # Redirect to login, if necessary
    if (not  $self->session->param('loggedin') ) {
        $self->log->debug("Showing login");
        $self->session->param(request => $rm);
        if ($rm eq 'new_post') {
            my $group = ${$self->param("path_parameters")}[0];
            $self->session->param(request_group => $group);
        }
        $self->prerun_mode('login');
        return;
    }
    $self->log->debug("cgiapp_prerun ends");
}

sub _set_run_mode {
    my ($self) = @_;

    $self->param(path_parameters => []);

    my $rm = $self->get_current_runmode();
    return $rm if $rm and $rm ne 'home'; # alredy has run-mode
    $rm = 'home'; # set to default ???

    # override rm based on PATH_INFO
    if ($ENV{PATH_INFO} =~ m{^/
                    ([^/]+)        # first word till after the first /
                    (?:/(.*))?     # the rest, after the (optional) second /
                    }x) {
        my $newrm = $1;
        my $params = $2 || "";
        if (any {$newrm eq $_} @urls) {
            my @params = split /\//, $params;
            $self->param(path_parameters => @params ? \@params : []);
            $rm = $newrm;
        } elsif ($ENV{PATH_INFO} eq "/cgi/index.pl") {
            # this should be ok here
            #$self->log->error("Invalid PATH_INFO: $ENV{PATH_INFO}");
        } else {
            $self->log->error("Invalid PATH_INFO: $ENV{PATH_INFO}");
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
    $self->log->debug("autoload called: @ARGV");
    $self->internal_error();
}


=head2 home

This the default run mode, it shows the home page that includes the list of
most recent posts.

=cut
sub home {
    my $self = shift;
    my $q = $self->query;
    
    $self->log->debug("home");
    my $t = $self->load_tmpl("home.tmpl",
        loop_context_vars => 1,
    );
    
    my $page = $q->param('page') || 1;
    $self->_search_results($t, {where => {}, page => $page});
    $self->log->debug("home to output");
    $t->output;
}

# currently returning the number of results but this might change
sub _search_results {
    my ($self, $t, $params) = @_;
    
    $params->{per_page} = $self->config("per_page");

    my $pager   = CPAN::Forum::Posts->mysearch($params);
    my @results = $pager->search_where();
    my $total   = $pager->total_entries;
    $self->log->debug("number of entries: total=$total");
    my $data = $self->build_listing(\@results);

    $t->param(messages       => $data);
    $t->param(total          => $total);
    $t->param(previous_page  => $pager->previous_page);
    $t->param(next_page      => $pager->next_page);
    $t->param(first_entry    => $pager->first);
    $t->param(last_entry     => $pager->last);
    $t->param(first_page     => 1)                      if $pager->current_page != 1;
    $t->param(last_page      => $pager->last_page)      if $pager->current_page != $pager->last_page;
    return $pager->total_entries;
}


=head2 all

An alias of the C<home()> run-mode.
=cut

sub all {
    home(@_);
}


=head2 build_listing

Given a reference to an array of Post objects creates and returns
a reference to an array that can be used with HTML::Template to
display the given posts.

=cut

sub build_listing {
    my ($self, $it) = @_;
    
    my @resp;
    foreach my $post (@$it) {
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
            postername   => $post->uid->username,
            };
    }
    #@resp = reverse @resp if $to; # Otherwise we fetched in DESC order
    return \@resp;
}


=head2 about

About box with some statistics.

=cut

sub about {
    my $self = shift;
    my $t = $self->load_tmpl("about.tmpl");
    
    $t->param(distro_cnt        => CPAN::Forum::Groups->count_all());
    $t->param(posts_cnt         => CPAN::Forum::Posts->count_all());
    $t->param(users_cnt         => CPAN::Forum::Users->count_all());
    $t->param(subscription_cnt  => CPAN::Forum::Subscriptions->count_all());
    $t->param(version           => $VERSION);
    # number of posts per group name, can create some xml feed from it that can
    # be used by search.cpan.org and Kobes to add a number of posts next to the link
    #select count(*),groups.name from posts, groups where groups.id=gid group by gid;
    #
    #count posts for a specific group:
    #select count(*) from posts, groups where groups.id=gid and groups.name="CPAN-Forum";

    $t->output;
}

=head2 stats

The stats run-mode showing some statistics
(actually the 50 busiest groups)

=cut

sub stats {
    my $self = shift;
    my $t = $self->load_tmpl("stats.tmpl");
    my @entries = CPAN::Forum::Posts->search_stat_posts(50);
    
    $t->param(entries => \@entries);
    $t->output;
}

sub faq {
    my $self = shift;
    my $t = $self->load_tmpl("faq.tmpl");
    $t->output;
}

sub error {
    my ($self) = @_;
    $self->log->critical($@) if $@;
    $self->internal_error();
}

=head2 internal_error

Gives a custom Internal error page.

Maybe this one should also receive the error message and print it to the log file.

See C<notes()> for simple notes.

=cut

sub internal_error {
    my ($self, $msg, $tag) = @_;
    if ($msg) {
        $self->log->warning($msg);
    }
    my $t = $self->load_tmpl("internal_error.tmpl");
    $t->param($tag => 1) if $tag;
    $t->param(generic => 1) if not $tag;
    $t->output;
}

=head2 notes

Print short notification messages to the user.

=cut
sub notes {
    my ($self, $msg) = @_;
    my $t = $self->load_tmpl("notes.tmpl");
    $t->param($msg => 1);
    $t->output;
}


=head2 load_tmpl

Semi standard CGI::Application method to replace the way we load the templates.

=cut

sub load_tmpl {
    my $self = shift;
    $self->log->debug("load_tmpl: @_");
    my $t = $self->SUPER::load_tmpl(@_
#             die_on_bad_params => -e ($self->param("ROOT") . "/die_on_bad_param") ? 1 : 0
    );
    $self->log->debug("template loaded");
    $t->param("loggedin" => $self->session->param("loggedin") || "");
    $t->param("username" => $self->session->param("username") || "anonymous");
    $t->param("test_site_warning" => -e $self->param("ROOT") . "/config_test_site");
    $t->param("admin" => $self->session->param('admin'));
    return $t;
}

=head2 login

Show the login form and possibly some error messages.

=cut
sub login {
    my ($self, $errs) = @_;
    my $q = $self->query;

    $self->log->debug("Sending cookie using sid:  " . $self->session->id());
    $self->session_cookie();
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
        $self->log->debug("No user found");
        return $self->login({bad_login => 1});
    }
    $self->log->debug("Username: " . $user->username);

    my $session = $self->session;
    $session->param(admin     => 0); # make sure it is clean

    $session->param(loggedin  => 1);
    $session->param(username  => $user->username);
    $session->param(uid       => $user->id);
    $session->param(fname     => $user->fname);
    $session->param(lname     => $user->lname);
    $session->param(email     => $user->email);
    foreach my $g (CPAN::Forum::Usergroups->search_ugs($user->id)) {
        $self->log->debug("UserGroups: " . $g->name);
        if ($g->name eq "admin") {
            $session->param(admin     => 1);
        }
    }

    my $request = $session->param("request") || "home";
    $self->log->debug("Request redirection: '$request'");
    my $response;
    eval {
        if ($request eq 'new_post') {
            my $request_group = $session->param("request_group") || '';
            $self->param("path_parameters" => [$request_group]);
        }
        ## no critic (ProhibitNoStrict)
        no strict 'refs';
        $response = &$request($self);
    };
    if ($@) {
        $self->log->error($@);
        die $@; # TODO: send error page?
    }
    $session->param("request" => "");
    $session->param("request_group" => "");
    $session->flush();
    $self->log->debug("Session flushed after login " . $session->param('loggedin'));
    return $response;
}


=head2 logout

Set the session to be logged out and remove personal information from the Session object.

=cut

sub logout {
    my $self = shift;
    
    my $session = $self->session;
    my $username = $session->param('username');
    $session->param(loggedin => 0);
    $session->param(username => '');
    $session->param(uid       => '');
    $session->param(fname     => ''); 
    $session->param(lname     => '');
    $session->param(email     => '');
    $session->param(admin     => '');
    $session->flush();
    $self->log->debug("logged out '$username'");

    $self->home;
}


=head2 register

Show the registration page and possibly some error messages.

=cut

sub register {
    my ($self, $errs) = @_;
    my $q = $self->query;

    my $t = $self->load_tmpl(
            "register.tmpl",
            associate => $q,
    );

    $t->param($errs) if $errs;
    return $t->output;
}


=head2 register_process

Process the registration form.

=cut

sub register_process {
    my ($self) = @_;
    my $q = $self->query;

    if (not $q->param('nickname') or not $q->param('email')) {
        return $self->register({"no_register_data" => 1});
    }
    
    # TODO arbitrary nickname constraint, allow other nicknames ?
    if ($q->param('nickname') !~ /^[a-z0-9]{1,25}$/) {
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

    my $FROM = $self->config("from");
    $self->log->debug("FROM field set to be $FROM");

    my %mail = (
        To       => $user->email,
        From     => $FROM,
        Subject  => $subject,
        Message  => $message,
    );
    $self->_my_sendmail(%mail);
}

=head2 notify_admin

Notify the administrator about a new registration

=cut

sub notify_admin {
    my ($self, $user) = @_;

    my $FROM = $self->config("from");

    my $msg = "\nUsername: " . $user->username . "\n"; 

    # TODO: the admin should be able to configure if she wants to get messages on
    # every new user (field update_on_new_user)
    my $admin = CPAN::Forum::Users->retrieve(1);
    my %mail = (
        To      => $admin->email,
        From     => $FROM,
        Subject => "New Forum user: " . $user->username,
        Message => $msg,
    );
    $self->_my_sendmail(%mail);
}

=head2 pwreminder

Show form to ask for password reminder e-mail

=cut
sub pwreminder {
    my ($self, $errs) = @_;
    my $q = $self->query;

    my $t = $self->load_tmpl(
            "pwreminder.tmpl",
            associate => $q,
    );

    $t->param($errs) if $errs;
    $t->param($q->param('field') => 1) if $q->param('field') and $q->param('field') =~ /^username|email$/;
    return $t->output;
}


=head2 pwreminder_process

Process the request to get a reminder about the password.

=cut

sub pwreminder_process {
    my ($self) = @_;
    my $q = $self->query;
    my $field = $q->param('field');
    if (not $field or $field !~ /^username|email$/ or not $q->param('value')) {
        return $self->pwreminder({"no_data" => 1});
    }

    my ($user) = CPAN::Forum::Users->search({$field => $q->param('value')});
    return $self->pwreminder({"no_data" => 1}) if not $user;

    # TODO: put this text in a template
    my $password = $user->password;
    my $username = $user->username;
    my $subject = "CPAN::Forum password reminder";
    my $message = <<MSG;

Your nickname is $username
Your secret key to CPAN::Forum is: $password
Use it wisely.

http://$ENV{HTTP_HOST}/


MSG

    my $FROM = $self->config("from");
    $self->log->debug("FROM field set to be $FROM");

    my %mail = (
        To       => $user->email,
        From     => $FROM,
        Subject  => $subject,
        Message  => $message,
    );
    $self->_my_sendmail(%mail);

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

    if (not @group_ids) {
        my @groups = CPAN::Forum::Groups->search(gtype => $CPAN::Forum::DBI::group_types{Distribution});
        foreach my $g (@groups) {
            push @group_ids, $g->id;
            $group_labels{$g->id} = $g->name;
        }

#       @groups = (
#       "Global", 
#       "----",
#       (sort map {$_->name} CPAN::Forum::Groups->search(gtype => $CPAN::Forum::DBI::group_types{Fields})),
#       "----",
#           (sort map {$_->name} CPAN::Forum::Groups->search(gtype => $CPAN::Forum::DBI::group_types{Distribution})),
#       );
    }
    @group_ids = sort {$group_labels{$a} cmp $group_labels{$b}}  @group_ids;
    
    return $q->popup_menu(-name => "new_group", -values => \@group_ids, -labels => \%group_labels);
}


=head2 new_post

Showing the new post page. (Alias of C<posts()>)

=cut

sub new_post {
    posts(@_);
}

=head2 response_form

Showing the response form. (Alias of C<posts()>)

=cut

sub response_form {
    posts(@_);
}


sub module_search_form {
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
    my $request = $self->session->param('request');
    if ($request) {
        $rm = $request;
        $self->log->debug("posts request reset rm=$rm");
    }

    my $new_group = "";
    my $new_group_id = "";
    
    if ($rm eq "new_post") {
        $new_group = ${$self->param("path_parameters")}[0] || "";
        $new_group_id = $q->param('new_group') if $q->param('new_group');
        $self->log->debug("A: new_group: '$new_group' and id: '$new_group_id'");
        
        if ($new_group) {
            if ($new_group =~ /^([\w-]+)$/) {
                $new_group = $1;
                my ($gr) = CPAN::Forum::Groups->search(name => $new_group);
                if ($gr) {
                    $new_group_id = $gr->id;
                } else {
                    return $self->internal_error(
                        "Group '$new_group' was not in database when accessed PATH_INFO: '$ENV{PATH_INFO}'",
                        );
                }
            } else {
                return $self->internal_error(
                    "Bad regex for '$new_group' ? Accessed PATH_INFO: '$ENV{PATH_INFO}'",
                    );
            }
        } elsif ($new_group_id) {
            my ($gr) = CPAN::Forum::Groups->retrieve($new_group_id);
            if ($gr) {
                $new_group = $gr->name;
            } else {
                return $self->internal_error(
                    "Group '$new_group_id' was not in database when accessed PATH_INFO: '$ENV{PATH_INFO}'",
                );
            }
        } elsif ($q->param('q')) {
            # process search later  
        } else {
            # TODO should be called whent the module_search is ready
            return $self->module_search_form();
        }
        $self->log->debug("B: new_group: '$new_group' and id: '$new_group_id'");
    }
    if ($rm eq "process_post") {
        $new_group_id = $q->param("new_group_id");
        if (not $new_group_id) {
            return $self->internal_error(
                "Missing new_group_id. Accessed PATH_INFO: '$ENV{PATH_INFO}'",
                );
        }

        if ($new_group_id =~ /^(\d+)$/) {
            $new_group_id = $1;
            my ($grp) = CPAN::Forum::Groups->retrieve($new_group_id);
            if ($grp) {
                $new_group = $grp->name;
            } else {
                return $self->internal_error(
                    "Bad value for new_group (id) '$new_group_id' ? Accessed PATH_INFO: '$ENV{PATH_INFO}'",
                    );
            } 
        } else {
            return $self->internal_error(
                "Bad value for new_group (id) '$new_group_id' ? Accessed PATH_INFO: '$ENV{PATH_INFO}'",
                );
        }
    }
    $self->log->debug("C: new_group: '$new_group' and id: '$new_group_id'");

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
            return $self->internal_error(
                "PATH_INFO: $ENV{PATH_INFO}",
                );
        }
        my $thread_count = CPAN::Forum::Posts->sql_count_thread($post->thread)->select_val;
        if ($thread_count > 1) {
            $t->param(thread_id    => $post->thread);
            $t->param(thread_count => $thread_count);
        }
        my %post = %{$self->_post($post)};
        $t->param(%post);
        
#       (my $dashgroup = $post->gid) =~ s/::/-/g;
#       $t->param(dashgroup    => $dashgroup);
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
    $self->log->debug("D: new_group: '$new_group' and id: '$new_group_id'");
    #$t->param("group_selector" => $self->_group_selector($new_group, $new_group_id));
    $t->param(new_group    => $new_group);
    $t->param(new_group_id => $new_group_id);
    $t->param(new_text     => CGI::escapeHTML($q->param("new_text")));
    
    # for previewing purposes:
    # This is funky, in order to use the same template for regular show of a message and for
    # the preview facility we create a loop around this code for the preview page (with hopefully
    # only one iteration in it) The following hash is in preparation of this internal loop.
    if (not @$errors or $$errors[0] eq "preview") {
        my %preview;
        $preview{subject}    = _subject_escape($q->param("new_subject")) || "";
        $preview{text}       = $self->_text_escape($q->param("new_text"))    || "";
        $preview{parentid}   = $q->param("new_parent")  || "";
#       $preview{thread_id}  = $q->param("new_text")    || "";
        $preview{postername} = $self->session->param("username");
        $preview{date}       = _post_date(time);
        $preview{id}         = "TBD";

        $t->param(preview_loop => [\%preview]);
    }

    #$t->param(new_subject => _subject_escape($q->param("new_subject")));
    $t->param(group       => $new_group) if $new_group;

    $self->set_ratings($t, $new_group) if $new_group;
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
        if ($q->param("new_group_id")) {
            push @errors, "bad_group"  if not CPAN::Forum::Groups->search(id => $q->param("new_group_id"));
        } else {
            push @errors, "no_group";
        }
    }
    
    my $new_subject = $q->param("new_subject");
    my $new_text = $q->param("new_text"); 
    
    push @errors, "no_subject" if not $new_subject;
    push @errors, "invalid_subject" if $new_subject and $new_subject !~ m{^$SUBJECT$};
    
    push @errors, "no_text"    if not $new_text;
    push @errors, "subject_too_long" if $new_subject and length($new_subject) > 80;

    $self->log->debug("username: " . 
                $self->session->param("username") . 
                " uid: " .  
                $self->session->param("uid"));
                
    my $button = $q->param("button");
    # BUG: we are putting in the usernames instead of the user ids in the uid field of the posts
    # but for this reason we'll have to use the username in every other place
    if (not @errors and $button eq "Submit") {
        my ($last_post) = CPAN::Forum::Posts->search(uid => $self->session->param("username"), {order_by => 'id DESC', limit => 1});
        if ($last_post) {
            $self->log->debug("username: " . 
                $self->session->param("username") . 
                " last post: " . $last_post->date . " now: " . time());
            if ($last_post->date > time() - $self->config("flood_control_time_limit")) {
                push @errors, "flood_control";
            }
        }
    }
    
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


    if ($button eq "Preview") {
        return $self->posts(["preview"]);
    }
    if ($button ne "Submit") {
        return $self->internal_error(
            "Someone sent in a button called '$button'",
            );
    }

    my $post_id;
    my $username = $self->session->param("username");
    my ($user) = CPAN::Forum::Users->search({ username => $username });
    if (not $user) {
        return $self->internal_error("Unknonw username: $username");
    }
    eval {
        my $post = CPAN::Forum::Posts->create({
            uid     => $user->id,
            gid     => $parent_post ? $parent_post->gid : $q->param("new_group_id"),
            subject => $q->param("new_subject"),
            text    => $new_text,
            date    => time,
        });
        $post->thread($parent_post ? $parent_post->thread : $post->id);
        $post->parent($parent) if $parent_post;
        $post->update;
        $post_id = $post->id;
    };
    if ($@) {
        #push @errors, "subject_too_long" if $@ =~ /subject_too_long/;
        if (not @errors) {
            return $self->internal_error(
                "PATH_INFO: '$ENV{PATH_INFO}'\nUNKNOWN_ERROR: $@",
            );
        }
        return $self->posts(\@errors);
    }
    
    $self->notify($post_id);

    $self->home;
}


sub _post_date {
    return scalar localtime $_[0];
}

sub _post {
    my ($self, $post) = @_;
    my @responses = map {{id => $_->id}} CPAN::Forum::Posts->search(parent => $post->id);

    my %post = (
        postername  => $post->uid->username,
        date        => _post_date($post->date),
        parentid    => $post->parent,
        responses   => \@responses,
        text        => $self->_text_escape($post->text),
    );

    $post{id}      = $post->id;
    $post{subject} = _subject_escape($post->subject);

    return \%post;
}

sub _subject_escape {
    my ($subject) = @_;
    return CGI::escapeHTML($subject);
}

# TODO: this is not correct, the Internal error should be raised all the way up, not as the
# text field...
sub _text_escape {
    my ($self, $text) = @_;

    return "" if not $text;
    my $markup = CPAN::Forum::Markup->new();
    my $html = $markup->posting_process($text);
    if (not defined $html) {
        $self->log->warning("Error displaying already accepted text: '$text'");
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
        return $self->internal_error(
            "PATH_INFO: $ENV{PATH_INFO}",
            );
    }

    my @posts_html;
    foreach my $p (@posts) {
        push @posts_html, $self->_post($p);
    }
    $t->param(posts => \@posts_html);
    
#   (my $dashgroup = $posts[0]->gid) =~ s/::/-/g;
    $t->param(group => $posts[0]->gid->name);
#   $t->param(dashgroup => $dashgroup);
    $t->param(title => _subject_escape($posts[0]->subject));

    $self->set_ratings($t, $posts[0]->gid->name);

    return $t->output;
}

sub get_rating {
    my ($self, $dist) = @_;
    require Text::CSV_XS;
    my $csv    = Text::CSV_XS->new();
    open my $fh, '<', '../../db/cpan_ratings.csv' or return;
    while (my $line = <$fh>) {
        next if $line !~ /^"$dist"/;
        last if not $csv->parse($line);
        return $csv->fields();
            
    }
    return;
}

sub set_ratings {
    my ($self, $t, $group) = @_;

    my ($distribution, $rating, $review_count) = $self->get_rating($group);
    if (not $rating) {
        $rating = "0.0";
        $review_count = 0;
    }
    if ($rating) {
        my $roundrating = sprintf "%1.1f", int($rating*2)/2;
        $t->param(rating       => $rating);
        $t->param(roundrating  => $roundrating);
        $t->param(review_count => $review_count);
    }
}

=head2 dist

List last few posts belonging to this group, provides a link to post a new 
message within this group

=cut

sub dist {
    my $self = shift;
    
    my $q = $self->query;

    my $group_name = ${$self->param("path_parameters")}[0] || '';
    if ($group_name =~ /^([\w-]+)$/) {
        $group_name = $1;
    } else {
        return $self->internal_error(
            "Probably bad regex when checking group name for $group_name called in $ENV{PATH_INFO}",
            );
    }
    $self->log->debug("show dist: '$group_name'");
#   $group_name =~ s/-/::/g;
#   (my $dashgroup = $group_name) =~ s/::/-/g;

    my $t = $self->load_tmpl("groups.tmpl",
        loop_context_vars => 1,
        global_vars => 1,
    );
    $t->param(hide_group => 1);
                
#   $t->param(dashgroup => $dashgroup);
    $t->param(group => $group_name);
    $t->param(title => "CPAN Forum - $group_name");

    my ($gr) = CPAN::Forum::Groups->search(name => $group_name);
    if (not $gr) {
        $self->log->warning("Invalid group $group_name called in $ENV{PATH_INFO}");
        $gr = $self->process_missing_dist($group_name);
        if (not $gr) {
            return $self->internal_error(
                "",
                "no_such_group",
            );
        }
    }
    my $gid = $gr->id;
    if ($gid =~ /^(\d+)$/) {
        $gid = $1;
    } else {
        return $self->internal_error(
            "Invalid gid received $gid called in $ENV{PATH_INFO}",
            );
    }

    $self->set_ratings($t, $group_name);
    my $page = $q->param('page') || 1;
    $self->_search_results($t, {where => {gid => $gid}, page => $page});
    $self->_subscriptions($t, $gr);
    $t->output;
}


sub _subscriptions {
    my ($self, $t, $group) = @_;


    my %people;
    foreach my $s (
            CPAN::Forum::Subscriptions_all->search(allposts => 1),
            CPAN::Forum::Subscriptions_pauseid->search(allposts => 1, pauseid => $group->pauseid),
            CPAN::Forum::Subscriptions->search(allposts => 1, gid => $group->id),
            ) {
        $people{$s->uid} =  {
            username => $s->uid->username,
        };
    }
    if (%people) {
        my @usernames = values %people;
        $t->param(users => [sort {$a->{username} cmp $b->{username}} @usernames])
    }
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
        return $self->internal_error(
            "No username: PATH_INFO: $ENV{PATH_INFO}",
            );
    }

    my $t = $self->load_tmpl("users.tmpl",
        loop_context_vars => 1,
        global_vars => 1,
    );
                
    $t->param(hide_username => 1);

    my ($user) = CPAN::Forum::Users->search(username => $username);

    if (not $user) {
        return $self->internal_error(
            "Non existing user was accessed: $ENV{PATH_INFO}",
            );
    }


    my $fullname = "";
    $fullname .= $user->fname if $user->fname;
    $fullname .= " " if $fullname;
    $fullname .= $user->lname if $user->lname;
    #$fullname = $username if not $fullname;

    $t->param(this_username => $username);
    $t->param(this_fullname => $fullname);
    $t->param(title => "Information about $username");

    my $page = $q->param('page') || 1;
    $self->_search_results($t, {where => {uid => $user->id}, page => $page});
    $t->output;
}

sub selfconfig {
    my ($self, $errs) = @_;
    my $t = $self->load_tmpl("change_password.tmpl");
    my ($user) = CPAN::Forum::Users->retrieve($self->session->param('uid'));
    $t->param(fname => $user->fname);
    $t->param(lname => $user->lname);

    $t->param($errs) if $errs;
    $t->output;
}

sub change_info {
    my ($self) = @_;
    my $q = $self->query;
    
    if ($q->param('fname') !~ /^[a-zA-Z]*$/) {
        return $self->selfconfig({"bad_fname" => 1});
    }
    if ($q->param('lname') !~ /^[a-zA-Z]*$/) {
        return $self->selfconfig({"bad_lname" => 1});
    }

    my ($user) = CPAN::Forum::Users->retrieve($self->session->param('uid'));
    $user->fname($q->param('fname'));
    $user->lname($q->param('lname'));
    $user->update;

    return $self->selfconfig({done => 1});

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

Manage the notify subscription.

Creates checkboxes, the names of the checkboxes start with
the subscription mode:

  allposts_   - every post
  starters_   - every time a new thread is started
  followups_  - every time there is a post where the user has already posted

The names are the followed wit one of the following:

  _all      - all the modules
  _NNN      - Where NNN is the id number of an author
  NNN       - where NNN is the id number of a group (distribution) 

The gids field contains the comma separated list of all the postfixes.

(Yes the difference between the two types of id is the extra _ only.)

C<update_subscription> will process the submitted form.

=cut

sub mypan {
    my $self = shift;

    my $t = $self->load_tmpl("mypan.tmpl",
        loop_context_vars => 1,
    );
    my $username = $self->session->param("username");
    my ($user) = CPAN::Forum::Users->search(username => $username);

    if (not $user) {
        return $self->internal_error(
            "Trouble accessing personal information of: '$username' $ENV{PATH_INFO}",
            );
    }
    my $fullname = "";
    $fullname .= $user->fname if $user->fname;
    $fullname .= " " if $fullname;
    $fullname .= $user->lname if $user->lname;

    $t->param(fullname => $fullname);
    $t->param(title    => "Information about $username");

    my @params = @{$self->param("path_parameters")};
    my @subscriptions;
    my $gids;


    if (@params == 2 and $params[0] eq "dist") { # specific distribution
        my $group = $params[1];
        my ($grp) = CPAN::Forum::Groups->search(name => $group);
        if (not $grp) {
            return $self->internal_error(
                "Accessing $ENV{PATH_INFO}\n",
            );
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
        my ($s) = CPAN::Forum::Subscriptions_all->search(uid => $user->id);
        $self->log->debug("all subscriptions " . ($s ? "found" : "not found"));
        push @subscriptions, {
            gid       => "_all",
            group     => "All",
            allposts  => $s ? $s->allposts  : '',
            starters  => $s ? $s->starters  : '',
            followups => $s ? $s->followups : '',
        };
        $gids = "_all";

        my $it = CPAN::Forum::Subscriptions_pauseid->search(uid => $user->id);
        while (my $s = $it->next) {
            $gids .= ($gids ? ",_" : "_") . $s->pauseid->id; 
            push @subscriptions, {
                gid       => "_" . $s->pauseid->id,
                group     => $s->pauseid->pauseid,
                allposts  => $s->allposts,
                starters  => $s->starters,
                followups => $s->followups,
            };
        }

        $it = CPAN::Forum::Subscriptions->search(uid => $user->id);
        while (my $s = $it->next) {
            $gids .= ($gids ? "," : "") . $s->gid->id; 
            push @subscriptions, {
                gid       => $s->gid,
                group     => $s->gid->name,
                allposts  => $s->allposts,
                starters  => $s->starters,
                followups => $s->followups,
            };
        }
    }

    $t->param(subscriptions => \@subscriptions);
    $t->param(gids => $gids);

    $t->output;
}

=head2 update_subscription

Process the submitted form created by C<mypan()>

=cut
sub update_subscription {
    my $self = shift;
    my $q = $self->query;
    
    my @gids = split /,/, $q->param("gids");
    if (not @gids) {
        return $self->internal_error();
    }

    my $username = $self->session->param("username");
    my ($user) = CPAN::Forum::Users->search(username => $username);

    foreach my $gid (@gids) {
        if ($gid eq "_all") {
            my ($s) = CPAN::Forum::Subscriptions_all->search(uid => $user->id);
            if (not $s) {
                $s = CPAN::Forum::Subscriptions_all->create({
                    uid       => $user->id,
                });
            }
            $self->_update_subs($s, $gid);
        } elsif ($gid =~ /^_(\d+)$/) {
            my $pauseid = $1;
            my ($s) = CPAN::Forum::Subscriptions_pauseid->search(pauseid => $pauseid, uid => $user->id);
            if (not $s) {
                $s = CPAN::Forum::Subscriptions->create({
                    uid       => $user->id,
                    pauseid   => $pauseid,
                });
            }
            $self->_update_subs($s, $gid);
        } elsif ($gid =~ /^(\d+)$/) {
            my ($s) = CPAN::Forum::Subscriptions->search(gid => $gid, uid => $user->id);
            if (not $s) {
                $s = CPAN::Forum::Subscriptions->create({
                    uid       => $user->id,
                    gid       => $gid,
                });
            }
            $self->_update_subs($s, $gid);
        } else {
            $self->log->error("Invalid gid: '$gid' provided in the gids entry of mypan");
            # shall we show an error page here?
        }
    }
    
    # if there is not name, no need for further processing
    if (not $q->param("name")) {
        return $self->notes("mypanok");
    }

    # TODO: error messages in case not all the values were filled in correctly
    # process new entry
    if (not $q->param("type")) {
        return $self->note("no_subs_type");
    }

    # TODO: if there is a subscription to the given distro or PAUSEID
    # we should not let the user overwrite it using the new entry box
    if ($q->param("type") eq "pauseid") {
        my $pauseid = uc $q->param("name");
        my ($author) = CPAN::Forum::Authors->search(pauseid => $pauseid);
        if ($author) {
            my $s = CPAN::Forum::Subscriptions_pauseid->find_or_create({
                uid       => $user->id,
                pauseid   => $author->id,
            });
            $self->_update_subs($s, "_new");
        } else {
            return $self->notes("no_such_pauseid");
        }
    }
    elsif ($q->param("type") eq "distro") {
        my $name = $q->param("name");
        $name =~ s/::/-/g;  
        my ($grp) = CPAN::Forum::Groups->search(name => $name);
        if ($grp) {
            my $s = CPAN::Forum::Subscriptions->find_or_create({
                uid       => $user->id,
                gid       => $grp->id,
            });
            $self->_update_subs($s, "_new");
        } else {
            return $self->notes("no_such_group");
        }
    }
    else {
        return $self->internal_error("", "invalid_subs_type");
    }

    return $self->notes("mypanok");
}

=head2 _update_subs

Given a subscription obkect (1 out of 3 possible classes)
and a gid (_all, _NNN or NNN) fetches the relevan checkboxes 
(See C<mypan()> for details) and update the subscription object.

=cut
sub _update_subs {
    my ($self, $s, $gid) = @_;
    my $q = $self->query;

    my $on = 0;
    foreach my $type (qw(allposts starters followups)) {
        if (defined $q->param($type ."_$gid") and $q->param($type . "_$gid") eq "on") {
            $s->set($type, 1);
            $on++;
        } else {
            $s->set($type, 0);
        }
    }
    if ($on) {
        return $s->update;
    }
    else {
        return $s->delete;   # remove the whole line if there are no subscriptions at all.
    }
}



sub module_search {
    my ($self) = @_;

    my $q = $self->query;
    my $txt = $q->param("q");
    $txt =~ s/^\s+|\s+$//g;

    # remove taint if there is
    if ($txt =~ /^([\w:.%-]+)$/) {
        $txt = $1;
    } else {
        $self->log->debug("Tained search: $txt");
    }

    if (not $txt) {
        return $self->module_search_form(['invalid_search_term']);
    }
    $self->log->debug("group name search term: $txt");
    $txt =~ s/::/-/g;
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
        return $self->module_search_form(['no_module_found']);
    }
    
    #$self->log->debug("GROUP NAMES: @group_names");

    my $t = $self->load_tmpl("module_select_form.tmpl",
    );
    $t->param("group_selector" => $self->_group_selector(\@group_names, \@group_ids));
    $t->output;
}

sub search {
    my ($self) = @_;
    my $q      = $self->query;
    my $name   = $q->param("name")    || '';
    my $what   = $q->param("what")    || '';
    $name      =~ s/^\s+|\s+$//g;
    my $any_result = 0;

    # kill the taint checking (why do I use taint checking if I kill it then ?)
    if ($name =~ /(.*)/) { $name    = $1; }
    $name =~ s/::/-/g if $what eq "module";
    
    my $t = $self->load_tmpl("search.tmpl",
        associate => $q,
        loop_context_vars => 1,
    );
    my $it;

    if (not $what and not $name) {
        $what = $self->session->param('search_what');
        $name = $self->session->param('search_name');
    }

    $self->session->param(search_what => $what);
    $self->session->param(search_name => $name);

    if ($what and $name) {
        if ($what eq "module") {
            my @things;
            my $it =  CPAN::Forum::Groups->search_like(name => '%' . $name . '%');
            while (my $group  = $it->next) {
                push @things, {name => $group->name};
            }
            $any_result = 1 if @things;
            $t->param(groups => \@things);
            $t->param($what => 1);
        } elsif ($what eq "user") {
            my @things;
            my $it =  CPAN::Forum::Users->search_like(username => '%' . lc($name) . '%');
            while (my $user  = $it->next) {
                push @things, {username => $user->username};
            }
            $any_result = 1 if @things;
            $t->param(users => \@things);
            $t->param($what => 1);
        } else {
            my %where;
            if ($what eq "subject") { %where = (subject => {'LIKE', '%' . $name . '%'}); }
            if ($what eq "text")    { %where = (text    => {'LIKE', '%' . $name . '%'}); }
            $self->log->debug("Search 1: " . join "|", %where);
            if (%where) {

                $self->log->debug("Search 2: " . join "|", %where);

                my $page = $q->param('page') || 1;
                $any_result = $self->_search_results($t, {where => \%where, page => $page});
                $t->param($what => 1);
            }
        }
        $t->param(no_results => not $any_result);
    }
    $t->output;
}

sub add_new_group {
    my ($self) = @_;
    if (not $self->session->param("admin")) {
        return $self->internal_error("", "restricted_area");
    }
    my $q = $self->query;
    my $group_name = $q->param("group");
    $self->log->debug("Adding group with name: '$group_name'");
    my $group = eval {
            CPAN::Forum::Groups->create({
                name  => $group_name,
                gtype => 3,
                });
            };
    if ($@) {
        $self->log->debug("Failed to add group with name: '$group_name'");
        return $self->internal_error("", "failed_to_add_group");
    }

    my $t = $self->load_tmpl("admin.tmpl");
    $t->param(updated => 1);
    $t->output;
}

sub admin_edit_user_process {
    my ($self) = @_;
    if (not $self->session->param("admin")) {
        return $self->internal_error("", "restricted_area");
    }
    my $q = $self->query;
    my $email = $q->param('email');
    my $uid   = $q->param('uid'); # TODO error checking here !

    $self->log->debug("admin_edit_user_process uid: '$uid'");
    my ($person) = CPAN::Forum::Users->retrieve($uid);
    if (not $person) {
        return $self->internal_error("", "no_such_user");
    }
    $person->email($email);
    $person->update;

    $self->admin_edit_user($person->username, ['done']);
}

sub admin_edit_user {
    my ($self, $username, $errors) = @_;
    if (not $self->session->param("admin")) {
        return $self->internal_error("", "restricted_area");
    }
    my $q = $self->query;
    if (not $username) {
        $username = ${$self->param("path_parameters")}[0] || '';
    }
    $self->log->debug("admin_edit_user username: '$username'");

    my ($person) = CPAN::Forum::Users->search(username => $username);
    if (not $person) {
        return $self->internal_error("", "no_such_user");
    }

    my $t = $self->load_tmpl("admin_edit_user.tmpl");
    $t->param(this_username => $username);
    $t->param(email => $person->email);
    $t->param(uid   => $person->id);

    if ($errors and ref($errors) eq "ARRAY") {
        $t->param($_ => 1) foreach @$errors;
    }

    $t->output;

}

sub admin_process {
    my ($self) = @_;
    if (not $self->session->param("admin")) {
        return $self->internal_error("", "restricted_area");
    }
    my $q = $self->query;

    # fields that can have only one value
    foreach my $field (qw(rss_size per_page from flood_control_time_limit )) {
        if (my ($conf) = CPAN::Forum::Configure->find_or_create({field => $field})) {
            $conf->value($q->param($field));
            $conf->update;
        }
    }

    $self->status($q->param('status'));
    

    my $t = $self->load_tmpl("admin.tmpl");
    $t->param(updated => 1);
    $t->output;
}


sub admin {
    my ($self) = @_;
    if (not $self->session->param("admin")) {
        return $self->internal_error("", "restricted_area");
    }
    my %data;
    foreach my $c (CPAN::Forum::Configure->retrieve_all()) {
        $data{$c->field} = $c->value;
    }
    my $t = $self->load_tmpl("admin.tmpl");
    $t->param("status_" . $self->status() => 1);
    $t->param(%data);
    $t->output;
}

=head2 rss

Provide RSS feed
/rss/all  latest N entries
/rss/dist/Distro-Name  latest N entries of that distro name
/rss/author/PAUSEID

=cut

sub rss {
    my $self = shift;
    
    my $limit  = $self->config("rss_size") || 10;
    my @params = @{$self->param("path_parameters")};
    my $it;
    if (@params > 1) {
        if ($params[0] eq 'dist') {
            my $dist = $params[1];
            $self->log->debug("rss of dist: '$dist'");
            my ($group) = CPAN::Forum::Groups->search({ name => $dist });
            $it = CPAN::Forum::Posts->search(gid => $group->id, {order_by => 'date DESC'});
        }
        elsif ($params[0] eq 'author') {
            my $pauseid = uc $params[1];
            $self->log->debug("rss of author: '$pauseid'");
            $it = CPAN::Forum::Posts->search_post_by_pauseid($pauseid);
        }
        else {
            $self->log->warnings("rss requested for $params[0]");
        }
    }
    else {
        $it = CPAN::Forum::Posts->retrieve_latest($limit);
    }

    require XML::RSS::SimpleGen;
    my $url = "http://$ENV{HTTP_HOST}/";
    my $rss = XML::RSS::SimpleGen->new( $url, "CPAN Forum", "Discussing Perl CPAN modules");
    $rss->language( 'en' );

    my $admin = CPAN::Forum::Users->retrieve(1); # TODO this is a hard coded user id of the administrator !
    # and this reveals the e-mail of the administrator. not a good idea I guess.
    $rss->webmaster($admin->email);

    while (my $post = $it->next() and $limit--) {
        my $title = sprintf "[%s] %s", $post->gid->name, $post->subject;
        $rss->item($url. "posts/" . $post->id(), $title); # TODO _subject_escape ?
    }

    $self->header_props(-type => 'application/rss+xml');
    
    return $rss->as_string();
}

=head2 notify

Send out e-mails upon receiving a submission.

=cut

sub notify {
    my ($self, $post_id) = @_;
    
    my $post = CPAN::Forum::Posts->retrieve($post_id);

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

    my $FROM = $self->config("from");
    $self->log->debug("FROM field set to be $FROM");
    my %mail = (
        From     => $FROM,
        Subject  => $subject,
        Message  => $message,
    );


    $self->fetch_subscriptions(\%mail, $post);
}

sub fetch_subscriptions {
    my ($self, $mail, $post) = @_;

    my %to; # keys are e-mail addresses that have already received an e-mail

    # subscriptions to "all" messages in the current group
    $self->log->debug("Processing messages for allposts");

    my $it;

    # People who asked for all the posts
    $it = CPAN::Forum::Subscriptions_all->search(allposts => 1);
    $self->_sendmail($it, $mail, \%to);

    # People who asked for all the posts in this group
    $it = CPAN::Forum::Subscriptions->search(allposts => 1, gid => $post->gid);
    $self->_sendmail($it, $mail, \%to);

    # People who asked for all the posts in this PAUSEID
    $it = CPAN::Forum::Subscriptions_pauseid->search(allposts => 1, pauseid => $post->gid->pauseid);
    $self->_sendmail($it, $mail, \%to);

    if ($post->thread == $post->id) { 
        $self->log->debug("Processing messages for thread starter");

        # People who are subscribed to all thread starters
        $it = CPAN::Forum::Subscriptions_all->search(starters => 1);
        $self->_sendmail($it, $mail, \%to);

        # People who are subscribed to the thread startes in this group
        $it = CPAN::Forum::Subscriptions->search(starters => 1, gid => $post->gid->id);
        $self->_sendmail($it, $mail, \%to);

        # People who are subscribed to the thread startes of this PAUSEID
        $it = CPAN::Forum::Subscriptions_pauseid->search(starters => 1, pauseid => $post->gid->pauseid);
        $self->_sendmail($it, $mail, \%to);
    }
    else {
        $self->log->debug("Processing messages for followups");

        # Collect the users who posted in this thread
        my %uids;
        my $pit = CPAN::Forum::Posts->search(thread => $post->thread);
        while (my $p = $pit->next) {
            $uids{$p->uid}=1;
            $self->log->debug("Ids: " . $p->uid);
        }
        
        $it = CPAN::Forum::Subscriptions_all->search(followups => 1);
        $self->_sendmail($it, $mail, \%to, \%uids);

        $it = CPAN::Forum::Subscriptions->search(followups => 1, gid => $post->gid->id);
        $self->_sendmail($it, $mail, \%to, \%uids);
        
        $it = CPAN::Forum::Subscriptions_pauseid->search(followups => 1, pauseid => $post->gid->pauseid);
        $self->_sendmail($it, $mail, \%to);
    }
}

sub _sendmail {
    my ($self, $it, $mail, $to, $uids) = @_;

    while (my $s = $it->next) {
        my $email = $s->uid->email;
        $self->log->debug("Sending to $email ?");
        $mail->{To} = $email;
        $self->log->debug("Processing uid: " . $s->uid->username) if $uids;
        next if $uids and not $uids->{$s->uid->username};
        $self->log->debug("Sending to $email id was found");
        next if $_[2]->{$email}++;
        $self->log->debug("Sending to $email first time sending");
        $self->_my_sendmail(%$mail);
        $self->log->debug("Sent to $email");
    }
}

sub status {
    my ($self, $value) = @_;
    if ($value) {
        if ($value eq "open") {
            if (-e $STATUS_FILE) {
                unlink $STATUS_FILE;
                # TODO check if the file does not exist any more after this action?
            }
            return "open";
        }

        open my $fh, ">", $STATUS_FILE;
        if (not $fh) {
            $self->log->warning("Could not open status file '$STATUS_FILE' $!");
            return;
        }
        print $fh $value;
        return $value;
    } else {
        return "open" if not -e $STATUS_FILE;
        open my $fh, "<", $STATUS_FILE;
        my $value = <$fh>;
        chomp $value;
        return $value;
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

sub site_is_closed {
    $_[0]->load_tmpl("site_is_closed.tmpl")->output;
}

sub teardown {
    my ($self) = @_;
    $self->log->debug("teardown called");
    my $rm = $self->get_current_runmode();
    if (not  $self->session->param('loggedin')  and $rm ne "login") {
        $self->log->debug("not logged in, deleting session");
        $self->session->delete();
    }
    # flush added as the Test::WWW::Mechanize::CGI did not work well without
    # it after we started to use file based session objects
    $self->session->flush();
}

sub _my_sendmail {
    my ($self, @args) = @_;

    return if $ENV{NO_CPAN_FORUM_MAIL};
    # for testing
    if (defined &_test_my_sendmail) {
        $self->_test_my_sendmail(@_);
        return;
    }
    else {
        return sendmail(@args);
    }
}

=head2 process_missing_dist

A very CPAN related piece of code.
Given a name of a distribution (with dashes), 
check if the given distribution is on search.cpan.org 
and try to add it to our database.

Return true on success.

=cut
sub process_missing_dist {
    my ($self, $dist_name) = @_;
    $self->log->debug("Fetch info regarding $dist_name from search.cpan.org");

    # Cehck if client is approved
    my %IPS = (
        '66.249.66.3'  => 1,   # GoogleBot
        '65.55.213.74' => 1,   # msnbot
#        '127.0.0.1'    => 1,   # localhost for testing
    );
    if (not $ENV{REMOTE_ADDR} or not $IPS{ $ENV{REMOTE_ADDR} }) {
        $self->log->debug("Client $ENV{REMOTE_ADDR} is not in the approved list");
        return;
    }

    # Fetch page from search.cpan.org and do a sanity check
    require WWW::Mechanize;
    my $w = WWW::Mechanize->new;
    my $url = "http://search.cpan.org/dist/$dist_name/";
    $self->log->debug("URL: '$url'");
    $w->get($url);
    #$self->log->debug($w->content);
    if (not $w->success) {
        $self->log->debug("Could not fetch $url");
        return;
    }
    my $discuss_link = $w->find_link( text_regex => qr{Discussion.*Forum} );
    if (not $discuss_link) {
        $self->log->debug("Could not find link to Discussion Forum");
        return;
    }
    $self->log->debug("Url to discussion list: " . $discuss_link->url);

    my $download_link = $w->find_link( text_regex => qr{Download} );
    if (not $download_link) {
        $self->log->debug("Could not find link to Download");
        return;
    }
    my $download_url = $download_link->url;
    $self->log->debug("Download url: $download_url");
    require CPAN::DistnameInfo;
    my $d = CPAN::DistnameInfo->new($download_url);
    if (not $d) {
        $self->log->debug("Could not parse download URL");
        return;
    }
    if ($dist_name ne $d->dist) {
         $self->log->debug("Distname $dist_name is different from " . $d->dist);
    }

    my $pauseid = $d->cpanid;
    if (not $pauseid) {
         $self->log->debug("Could not get PAUSEID from download_url");
         return;
    }
    my $author = eval { CPAN::Forum::Authors->find_or_create({
                    pauseid => $pauseid,
                 }); };
    if (not $author) {
        $self->log->debug("Could not find_or_create author: '$pauseid'");
        return;
    }

    my $group = eval { CPAN::Forum::Groups->create({
        name    => $dist_name,
        gtype   => $CPAN::Forum::DBI::group_types{Distribution}, 
        version => $d->version,
        pauseid => $author->id,
    }); };
    if ($group) {
        $self->log->notice("Distribution $dist_name added");
        return $group;
    }
    else {
        $self->log->debug("Could not add distribution $dist_name: $@");
        return;
    }
}




1;

=head1 ACKNOWLEDGEMENTS

Thanks to Offer Kaye for his initial help with HTML and CSS.  Thanks
to Shlomi Fish for some patches. Thanks to all
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

Copyright 2004-2006, Gabor Szabo (gabor@pti.co.il)
 
This software is free. It is licensed under the same terms as Perl itself.

=cut

