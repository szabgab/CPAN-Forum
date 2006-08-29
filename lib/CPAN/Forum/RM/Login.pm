package CPAN::Forum::RM::Login;
use strict;
use warnings;


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
        $response = $self->$request();
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

1;

