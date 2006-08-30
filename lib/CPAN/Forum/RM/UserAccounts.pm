package CPAN::Forum::RM::UserAccounts;
use strict;
use warnings;

sub selfconfig {
    my ($self, $errs) = @_;
    my $t = $self->load_tmpl("change_password.tmpl");
    my ($user) = CPAN::Forum::DB::Users->retrieve($self->session->param('uid'));
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

    my ($user) = CPAN::Forum::DB::Users->retrieve($self->session->param('uid'));
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
    
    my ($user) = CPAN::Forum::DB::Users->retrieve($self->session->param('uid'));
    $user->password($q->param('password'));
    $user->update;

    return $self->selfconfig({done => 1});

}



1;

