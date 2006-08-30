package CPAN::Forum::RM::Admin;
use strict;
use warnings;

sub admin_edit_user_process {
    my ($self) = @_;
    if (not $self->session->param("admin")) {
        return $self->internal_error("", "restricted_area");
    }
    my $q = $self->query;
    my $email = $q->param('email');
    my $uid   = $q->param('uid'); # TODO error checking here !

    $self->log->debug("admin_edit_user_process uid: '$uid'");
    my ($person) = CPAN::Forum::DB::Users->retrieve($uid);
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

    my ($person) = CPAN::Forum::DB::Users->search(username => $username);
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
        if (my ($conf) = CPAN::Forum::DB::Configure->find_or_create({field => $field})) {
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
    foreach my $c (CPAN::Forum::DB::Configure->retrieve_all()) {
        $data{$c->field} = $c->value;
    }
    my $t = $self->load_tmpl("admin.tmpl");
    $t->param("status_" . $self->status() => 1);
    $t->param(%data);
    $t->output;
}

1;

