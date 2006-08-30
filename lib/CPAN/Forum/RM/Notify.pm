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
    my $self = shift;
    
    my $limit  = $self->config("rss_size") || 10;
    my @params = @{$self->param("path_parameters")};
    my $it;
    if (@params > 1) {
        if ($params[0] eq 'dist') {
            my $dist = $params[1];
            $self->log->debug("rss of dist: '$dist'");
            my ($group) = CPAN::Forum::DB::Groups->search({ name => $dist });
            $it = CPAN::Forum::DB::Posts->search(gid => $group->id, {order_by => 'date DESC'});
        }
        elsif ($params[0] eq 'author') {
            my $pauseid = uc $params[1];
            $self->log->debug("rss of author: '$pauseid'");
            $it = CPAN::Forum::DB::Posts->search_post_by_pauseid($pauseid);
        }
        else {
            $self->log->warning("Invalid rss feed requested for $params[0]");
            return $self->notes('no_such_rss_feed');
        }
    }
    else {
        $it = CPAN::Forum::DB::Posts->retrieve_latest($limit);
    }

    require XML::RSS::SimpleGen;
    my $url = "http://$ENV{HTTP_HOST}/";
    my $rss = XML::RSS::SimpleGen->new( $url, "CPAN Forum", "Discussing Perl CPAN modules");
    $rss->language( 'en' );

    my $admin = CPAN::Forum::DB::Users->retrieve(1); # TODO this is a hard coded user id of the administrator !
    # and this reveals the e-mail of the administrator. not a good idea I guess.
    $rss->webmaster($admin->email);

    while (my $post = $it->next() and $limit--) {
        my $title = sprintf "[%s] %s", $post->gid->name, $post->subject;
        $rss->item($url. "posts/" . $post->id(), $title); # TODO _subject_escape ?
    }

    $self->header_props(-type => 'application/rss+xml');
    
    return $rss->as_string();
}



1;

