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
    my $person = CPAN::Forum::DB::Users->info_by(id => $uid); # SQL
    if (not $person) {
        return $self->internal_error("", "no_such_user");
    }
    eval {
        my $person = CPAN::Forum::DB::Users->update($uid, email => lc $email); #SQL
    };
    if ($@ =~ /column email is not unique/) {
        return $self->notes("duplicate_email");
    }

    $self->admin_edit_user($person->{username}, ['done']);
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

    my $person = CPAN::Forum::DB::Users->info_by(username => $username); # SQL
    if (not $person) {
        return $self->internal_error("", "no_such_user");
    }

    my $t = $self->load_tmpl("admin_edit_user.tmpl");
    $t->param(this_username => $username);
    $t->param(email => $person->{email});
    $t->param(uid   => $person->{id});

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
    foreach my $field (qw(rss_size per_page from flood_control_time_limit 
                disable_email_notification)) {
        CPAN::Forum::DB::Configure->set_field_value($field, $q->param($field)); # SQL
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

    my $data = CPAN::Forum::DB::Configure->get_all_pairs;
    $self->log->debug(Data::Dumper->Dump([$data], ['config']));

    my $t = $self->load_tmpl("admin.tmpl");
    $t->param("status_" . $self->status() => 1);
    $t->param(%$data);
    $t->output;
}

1;

