package CPAN::Forum::RM::Notify;
use strict;
use warnings;

=head2 notify

Send out e-mails upon receiving a submission.

=cut

sub notify {
    my ($self, $post_id) = @_;
    
    my $post = CPAN::Forum::DB::Posts->retrieve($post_id);

    my $message = 
        $self->_text2mail ($post->text) .
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

=head2 notify_admin

Notify the administrator about a new registration

=cut

sub notify_admin {
    my ($self, $user) = @_;

    my $FROM = $self->config("from");

    my $msg = "\nUsername: " . $user->username . "\n"; 

    # TODO: the admin should be able to configure if she wants to get messages on
    # every new user (field update_on_new_user)
    my $admin = CPAN::Forum::DB::Users->retrieve(1);
    my %mail = (
        To      => $admin->email,
        From     => $FROM,
        Subject => "New Forum user: " . $user->username,
        Message => $msg,
    );
    $self->_my_sendmail(%mail);
}

=head2 rss

Provide RSS feed
/rss/all  latest N entries
/rss/dist/Distro-Name  latest N entries of that distro name
/rss/author/PAUSEID

=cut

sub rss {
    my ($self) = @_;
    $self->_feed('rss');
}

sub atom {
    my ($self) = @_;
    $self->_feed('atom');
}

sub _feed {
    my ($self, $type) = @_;

    die "invalid _feed call '$type'" 
        if not defined $type or ($type ne 'rss' and  $type ne 'atom');

    my $limit  = $self->config("${type}_size") || 10;
    my $it = $self->get_feed($limit);
    #if ($it) {
        my $call = "generate_$type";
        return $self->$call($it, $limit);
    #}
    #else {
    #    $self->log->warning("Invalid $type feed requested for $ENV{PATH_INFO}");
    #    return $self->notes("no_such_${type}_feed");
    #}
}

sub generate_atom {
    # TODO
    die "TODO";
}


sub generate_rss {
    my ($self, $it, $limit) = @_;

    require XML::RSS::SimpleGen;
    my $url = "http://$ENV{HTTP_HOST}/";
    my $rss = XML::RSS::SimpleGen->new( $url, "CPAN Forum", "Discussing Perl CPAN modules");
    $rss->language( 'en' );

    # TODO: replace this e-mail address with a configurable value
    $rss->webmaster('admin@cpanforum.com');

    if ($it) {
        while (my $post = $it->next() and $limit--) {
            my $title = sprintf "[%s] %s", $post->gid->name, $post->subject;
            $rss->item($url. "posts/" . $post->id(), $title); # TODO _subject_escape ?
        }
    }
    else {
        # TODO: maybe we should put a link here to search that module ot that
        # PAUSEID?
        $rss->item($url, "No posts yet");
    }

    $self->header_props(-type => 'application/rss+xml');
    
    return $rss->as_string();
}

sub get_feed {
    my ($self, $limit) = @_;

    my @params = @{$self->param("path_parameters")};

    return if not @params;

    if ($params[0] eq 'dist') {
        my $dist = $params[1] || '';
        $self->log->debug("rss of dist: '$dist'");
        my ($group) = CPAN::Forum::DB::Groups->search({ name => $dist });
        if ($group) {
            $self->log->debug("aha");
            return scalar CPAN::Forum::DB::Posts->search(gid => $group->id, {order_by => 'date DESC'});
        }
    }

    if ($params[0] eq 'author') {
        my $pauseid = uc($params[1]) || '';
        if ($pauseid) {
            $self->log->debug("rss of author: '$pauseid'");
            return scalar CPAN::Forum::DB::Posts->search_post_by_pauseid($pauseid);
        }
    }

    if ($params[0] eq 'all') {
        return scalar CPAN::Forum::DB::Posts->retrieve_latest($limit);
    }

    if ($params[0] eq 'threads') {
        return scalar CPAN::Forum::DB::Posts->search_latest_threads($limit);
    }

    return;
}

=head2 _text2mail

replace the markup used in the posting by things we can use in 
e-mail messages.

=cut

sub _text2mail {
    return $_[1];
}


1;

