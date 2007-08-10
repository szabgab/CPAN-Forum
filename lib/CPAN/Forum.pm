package CPAN::Forum;
use strict;
use warnings;

our $VERSION = '0.12';

use base 'CGI::Application';
use CGI::Application::Plugin::Session;
use CGI::Application::Plugin::LogDispatch;
use Data::Dumper qw();
use POSIX        qw();
use Mail::Sendmail qw(sendmail);
use CGI ();
use List::MoreUtils qw(any);
use WWW::Mechanize;
use CPAN::DistnameInfo;

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

our $logger;
$SIG{__WARN__} = sub {
    if ($logger) {
        $logger->warning($_[0]);
    } else {
        print STDERR $_[0];
    }
};

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

    perl bin/setup.pl --config CONFIG --dir db

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
    $self->param('start_time', time);
    
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
    $CPAN::Forum::logger = $self->log;
    

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
    my ($package, $filename, $line, $sub) = caller(6);
    my $root = $self->param("ROOT");
    $filename =~ s/^$root//;
    return sprintf "[%s] - %s - [%s] [%s] [%s] [%s(%s)] %s\n",
            POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime), 
            $h{level}, 
            ($ENV{REMOTE_ADDR} || ''),
            ($ENV{HTTP_REFERER} || ''),
            ($self->param('REQUEST')),
            $filename, $line,
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
    
    CPAN::Forum::DB::Configure->param($field); # SQL
}

# modes that can be accessed without a valid session
my @free_modes = qw(
    home 
    pwreminder pwreminder_process 
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
    new_post pwreminder 
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
); 

use base 'CPAN::Forum::RM::Author';
use base 'CPAN::Forum::RM::Dist';
use base 'CPAN::Forum::RM::Login';
use base 'CPAN::Forum::RM::Users';
use base 'CPAN::Forum::RM::Admin';
use base 'CPAN::Forum::RM::Other';
use base 'CPAN::Forum::RM::Notify';
use base 'CPAN::Forum::RM::Search';
use base 'CPAN::Forum::RM::Subscriptions';
use base 'CPAN::Forum::RM::Tags';
use base 'CPAN::Forum::RM::UserAccounts';
use base 'CPAN::Forum::RM::Update';

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

We use it to change the run mode according to the requested URL.
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

    my $q = $self->query;

    # override rm based on REQUEST
    my $request = $self->param('REQUEST');
    if ($request =~ m{^/
                    ([^/]+)        # first word till after the first /
                    (?:/(.*))?     # the rest, after the (optional) second /
                    }x) {
        my $newrm = $1;
        my $params = $2 || "";
        if (any {$newrm eq $_} @urls) {
            my @params = split /\//, $params;
            $self->param(path_parameters => @params ? \@params : []);
            $rm = $newrm;
        } elsif ($request eq "/cgi/index.pl") {
            # this should be ok here
            #$self->log->error("Invalid request: $request}");
        } else {
            $self->log->error("Invalid request: $request");
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
    my $rm = $self->get_current_runmode();
    $self->log->debug("autoload called run-mode='$rm' ARGV='@ARGV'");
    $self->internal_error();
}


=head2 home

This the default run mode, it shows the home page.
Currently aliased to C<all()>;


=cut
sub home {
    all(@_);
}


=head2 all

List the most recent posts.

=cut

sub all {
    my $self = shift;
    my $q = $self->query;
    
    $self->log->debug("all");
    my $t = $self->load_tmpl("home.tmpl",
        loop_context_vars => 1,
    );
    
    my $page = $q->param('page') || 1;
    $self->_search_results($t, {where => {}, page => $page});
    $self->log->debug("home to output");
    $t->output;
}

=head2 recent_thread

Display the posts of the most recent threads
Not yet working.

=cut

sub recent_threads {
    my ($self) = @_;
    my $q = $self->query;

    $self->log->debug("recent_threads");
    my $t = $self->load_tmpl("home.tmpl",
        loop_context_vars => 1,
    );
    $t->output; 
}


=head2 build_listing

Given a reference to an array of Post objects creates and returns
a reference to an array that can be used with HTML::Template to
display the given posts.

=cut

sub build_listing {
    my ($self, $it) = @_;
    
    my @resp;
    my @threads = map {$_->thread} @$it;
    my $threads = CPAN::Forum::DB::Posts->count_threads(@threads); #SQL
    
    foreach my $post (@$it) {
#warn "called for each post";
        my $thread_count = $threads->{$post->thread}{cnt};
        push @resp, {
            subject      => _subject_escape($post->subject), 
            id           => $post->id, 
            group        => $post->gid->name, 
            thread       => ($thread_count > 1 ? 1 : 0),
            thread_id    => $post->thread,
            thread_count => $thread_count-1,
            #date         => POSIX::strftime("%e/%b", localtime $post->date),
            #date         => scalar localtime $post->date,
            date         => _ellapsed($post->date),
            postername   => $post->uid->username,
            };
    }
    return \@resp;
}

sub _ellapsed {
    my ($t) = @_;
    my $now = time;
    my $diff = $now-$t;
    return  'now' if not $diff;

    my $sec = $diff % 60;
    $diff = ($diff -$sec) / 60;
    return  sprintf(" %s sec ago", $sec) if not $diff;

    my $min = $diff % 60;
    $diff = ($diff-$min)/60;
    return  sprintf("%s min ago", $min) if not $diff;  

    my $hours = $diff % 24;
    $diff = ($diff - $hours) / 24;
    return  sprintf("%s hours ago", $hours ) if not $diff;  

    return  sprintf("%s days ago", $diff );  
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
    my ($self, $msg, %params) = @_;
    my $t = $self->load_tmpl("notes.tmpl");
    $t->param($msg => 1);
    $t->param(%params);
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
        CPAN::Forum::DB::Users->add_user({    # SQL
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
    my $password = $user->{password};
    my $subject = "CPAN::Forum registration";
    my $message = <<MSG;

Thank you for registering on the CPAN::Forum at
http://$ENV{HTTP_HOST}/

your password is: $password


MSG

    my $FROM = $self->config("from");
    $self->log->debug("FROM field set to be $FROM");

    my %mail = (
        To       => $user->{email},
        From     => $FROM,
        Subject  => $subject,
        Message  => $message,
    );
    $self->_my_sendmail(%mail);
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
                my ($gr) = CPAN::Forum::DB::Groups->info_by(name => $new_group); # SQL
                if ($gr) {
                    $new_group_id = $gr->{id};
                } else {
                    return $self->internal_error(
                        "Group '$new_group' was not in database",
                        );
                }
            } else {
                return $self->internal_error(
                    "Bad regex for '$new_group' ?",
                    );
            }
        } elsif ($new_group_id) {
            my ($gr) = CPAN::Forum::DB::Groups->info_by(id => $new_group_id); # SQL
            if ($gr) {
                $new_group = $gr->{name};
            } else {
                return $self->internal_error(
                    "Group '$new_group_id' was not in database",
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
                "Missing new_group_id.",
                );
        }

        if ($new_group_id =~ /^(\d+)$/) {
            $new_group_id = $1;
            my ($grp) = CPAN::Forum::DB::Groups->info_by(id => $new_group_id); # SQL
            if ($grp) {
                $new_group = $grp->{name};
            } else {
                return $self->internal_error(
                    "Bad value for new_group (id) '$new_group_id' ?",
                    );
            } 
        } else {
            return $self->internal_error(
                "Bad value for new_group (id) '$new_group_id' ?",
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
        my $post = CPAN::Forum::DB::Posts->get_post($id); # SQL
        if (not $post) {
            return $self->internal_error(
                "in request",
                );
        }
        my $thread_count = CPAN::Forum::DB::Posts->count_thread($post->{thread}); # SQL
        if ($thread_count > 1) {
            $t->param(thread_id    => $post->{thread});
            $t->param(thread_count => $thread_count);
        }
        my %post = %{$self->_post($post)};
        $t->param(%post);
        
#       (my $dashgroup = $post->gid) =~ s/::/-/g;
#       $t->param(dashgroup    => $dashgroup);
        my $new_subject = $post->{subject};
        if ($new_subject !~ /^\s*re:\s*/i) {
            $new_subject = "Re: $new_subject";
        }
        
        $t->param(new_subject  => _subject_escape($new_subject));
        $t->param(title        => _subject_escape($post->{subject}));
        $t->param(post         => 1);
        
        my $group = CPAN::Forum::DB::Groups->info_by(id => $post->{gid}); # SQL
        $new_group        = $group->{name};
        $new_group_id     = $group->{id};     
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
        $parent_post = CPAN::Forum::DB::Posts->get_post($parent); # SQL
        push @errors, "bad_thing"  if not $parent_post;
    } else {       # assume new post
        if ($q->param("new_group_id")) {
            push @errors, "bad_group"  if not CPAN::Forum::DB::Groups->info_by(id => $q->param("new_group_id")); # SQL
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
    if (not @errors and $button eq "Submit") {
        my $last_post = CPAN::Forum::DB::Posts->get_latest_post_by_uid($self->session->param('uid')); # SQL
        # TODO, maybe also check if the post is the same as the last post to avoid duplicates
        if ($last_post) {
            $self->log->debug("username: " . 
                $self->session->param("username") . 
                " last post: " . $last_post->{date} . " now: " . time());
            if ($last_post->{date} > time() - $self->config("flood_control_time_limit")) {
                push @errors, "flood_control";
            } elsif ($last_post->{text} eq $new_text) {
                push @errors, "duplicate_post";
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

    my $username = $self->session->param("username");
    my $user = CPAN::Forum::DB::Users->info_by( username => $username ); # SQL
    if (not $user) {
        return $self->internal_error("Unknown username: '$username'");
    }

    
    my %data = (
            uid     => $user->{id},
            gid     => ($parent_post ? $parent_post->{gid} : $q->param("new_group_id")),
            subject => $q->param("new_subject"),
            text    => $new_text,
            date    => time,
    );
    my $post_id = eval { CPAN::Forum::DB::Posts->add_post(\%data, $parent_post, $parent); }; #SQL
    if ($@) {
        #push @errors, "subject_too_long" if $@ =~ /subject_too_long/;
        if (not @errors) {
            return $self->internal_error(
                "UNKNOWN_ERROR: $@",
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
    my $responses = CPAN::Forum::DB::Posts->list_posts_by(parent => $post->{id}); # SQL

    my $user = CPAN::Forum::DB::Users->info_by(id => $post->{uid}); # SQL
    my %post = (
        postername  => $user->{username},
        date        => _post_date($post->{date}),
        parentid    => $post->{parent},
        responses   => $responses,
        text        => $self->_text_escape($post->{text}),
    );

    $post{id}      = $post->{id};
    $post{subject} = _subject_escape($post->{subject});

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

    my @posts = CPAN::Forum::DB::Posts->search(thread => $id);
    if (not @posts) {
        return $self->internal_error(
            "in request",
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

sub _subscriptions {
    my ($self, $t, $group) = @_;

    my $users = CPAN::Forum::DB::Subscriptions->get_subscriptions('allposts', $group->{id}, $group->{pauseid}); # SQL
    my @usernames = map {{ username => $_->{username} }} @$users;
    #$self->log->debug(Data::Dumper->Dump([\@users], ['users']));
    $t->param(users => \@usernames);
}

sub add_new_group {
    my ($self) = @_;
    if (not $self->session->param("admin")) {
        return $self->internal_error("", "restricted_area");
    }
    my $q = $self->query;
    my $group_name = $q->param("group");
    # TODO pausid is currently free text on the form
    # but it has been disabled for now
    # we will have to provide the full list of PAUSEID on the form
    # or check the id from the string
    my $pauseid    = $q->param("pauseid");
    if ($group_name !~ /^[\w-]+$/) {
        return $self->notes("invalid_group_name");
    }

    $self->log->debug("Adding group with name: '$group_name'");
    my $group = eval {
            CPAN::Forum::DB::Groups->add(   # SQL
                name  => $group_name,
                gtype => 3,
                );
            };
    if ($@) {
        $self->log->debug("Failed to add group with name: '$group_name'");
        return $self->internal_error("", "failed_to_add_group");
    }

    my $t = $self->load_tmpl("admin.tmpl");
    $t->param(updated => 1);
    $t->output;
}

sub fetch_subscriptions {
    my ($self, $mail, $post) = @_;

    my %to; # keys are e-mail addresses that have already received an e-mail

    $self->log->debug("Processing messages for allposts");
    my $users = CPAN::Forum::DB::Subscriptions->get_subscriptions('allposts', $post->{gid}, $post->{pauseid}); # SQL
    $self->_sendmail($users, $mail, \%to);

    if ($post->{thread} == $post->{id}) { 
        $self->log->debug("Processing messages for thread starter");
        my $users = CPAN::Forum::DB::Subscriptions->get_subscriptions('starters', $post->{gid}, $post->{pauseid}); # SQL
        $self->_sendmail($users, $mail, \%to);
    } else {
        $self->log->debug("Processing messages for followups, users who posted in this thread");

        my $uids = CPAN::Forum::DB::Posts->list_uids_who_posted_in_thread($post->{thread});
        $self->log->debug(Data::Dumper->Dump([$uids], ['uids']));
        my %uids = map {{ $_ => 1 }} @$uids;
 
        my $users = CPAN::Forum::DB::Subscriptions->get_subscriptions('followups', $post->{gid}, $post->{pauseid}); # SQL
        my @users_who_posted = grep { !$uids{ $_->{id} } } @$users;
        $self->_sendmail(\@users_who_posted, $mail, \%to);
    }
 
    $self->log->debug("Number of e-mails sent: ", scalar keys %to);
}

sub _sendmail {
    my ($self, $users, $mail, $to) = @_;

    foreach my $user (@$users) {
        #$self->log->debug(Data::Dumper->Dump([$mail], ['mail']));
        my $email = $user->{email};
        $mail->{To} = $email;
        $self->log->debug("Sending to $email id was found");
        next if $to->{$email}++; #TODO: stop using hardcoded reference to position!!!!!
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

sub privacy_policy {
    $_[0]->load_tmpl("privacy_policy.tmpl")->output;
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

    my $ellapsed_time = time() - $self->param('start_time');
    # first let's try to resolve the really big problems
    if ($ellapsed_time > 3) {
        my $rm = $self->get_current_runmode();
        $self->log->warning("Long request. Ellapsed time: $ellapsed_time on run-mode: $rm"); 
    }
}

sub _my_sendmail {
    my ($self, %args) = @_;
    #$self->log->debug(Data::Dumper->Dump([\%args], ['_my_sendmail']));
    #$self->log->debug("_my_sendmail to '$args{To}'");

    return if $ENV{NO_CPAN_FORUM_MAIL};
    # for testing
    return if $self->config("disable_email_notification");

    if (defined &_test_my_sendmail) {
        $self->_test_my_sendmail(@_);
        return;
    }
    else {
        return sendmail(%args);
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

    return if not $self->_approved_client();

    my $download_url = $self->_check_on_search_cpan_org($dist_name);
    return if not $download_url;

    my ($version, $pauseid) = $self->_check_dist_info($download_url, $dist_name);

    my $author = CPAN::Forum::DB::Authors->get_author_by_pauseid($pauseid); # SQL
    if (not $author) {
        $author = eval { CPAN::Forum::DB::Authors->add( pauseid => $pauseid ) }; # SQL
    }
    if (not $author) {
        $self->log->debug("Could not find or add author: '$pauseid'");
        return;
    }

    my $group = eval { CPAN::Forum::DB::Groups->add(   # SQL
        name    => $dist_name,
        gtype   => $CPAN::Forum::DBI::group_types{Distribution}, 
        version => $version,
        pauseid => $author->{id},
    ); };
    if ($group) {
        $self->log->notice("Distribution $dist_name added");
        return $group;
    }
    else {
        $self->log->debug("Could not add distribution $dist_name: $@");
        return;
    }
}

sub _check_dist_info {
    my ($self, $download_url, $dist_name) = @_;
    my $d = CPAN::DistnameInfo->new($download_url);
    if (not $d) {
        $self->log->debug("Could not parse download URL");
        return;
    }
    if ($dist_name ne $d->dist) {
        $self->log->debug("Distname '$dist_name' is different from '" . $d->dist . "'");
        return; # this was not here!!
    }

    my $pauseid = $d->cpanid;
    if (not $pauseid) {
         $self->log->debug("Could not get PAUSEID from download_url");
         return;
    }
    return ($d->version, $pauseid);
}


sub _approved_client {
    my ($self) = @_;

    # Check if client is approved
    my %IPS = (
        '66.249.66.3'  => 1,   # GoogleBot
        '65.55.213.74' => 1,   # msnbot
#        '127.0.0.1'    => 1,   # localhost for testing
    );
    if (not $ENV{REMOTE_ADDR} or not $IPS{ $ENV{REMOTE_ADDR} }) {
        $self->log->debug("Client $ENV{REMOTE_ADDR} is not in the approved list");
        return;
    }
    return 1;
}


sub _check_on_search_cpan_org {
    my ($self, $dist_name) = @_;

    # Fetch page from search.cpan.org and do a sanity check
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
    return $download_url;
}

sub version {
    return $VERSION;
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

