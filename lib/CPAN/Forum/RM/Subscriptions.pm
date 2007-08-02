package CPAN::Forum::RM::Subscriptions;
use strict;
use warnings;

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

 /mypan
 /mypan/dist/MODULE-NAME

=cut

sub mypan {
    my $self = shift;

    my $username = $self->session->param("username");
    my $user = CPAN::Forum::DB::Users->info_by(username => $username); # SQL

    if (not $user) {
        return $self->internal_error(
            "Trouble accessing personal information of: '$username'",
            );
    }

    my @params = @{$self->param("path_parameters")};
    my ($gids, $subscriptions);
    if (@params == 2 and $params[0] eq "dist") {
        my $group_name = $params[1];
        my $group = CPAN::Forum::DB::Groups->info_by(name => $group_name); # SQL
        if (not $group) {
            return $self->internal_error("Accessing");
        }
        ($gids, $subscriptions) = $self->_get_module_subscription($user, $group_name, $group);
    } elsif (@params == 2 and $params[0] eq "author") {
        my $pauseid_str = $params[1];
        my $subs = CPAN::Forum::DB::Authors->get_author_by_pauseid($pauseid_str); # SQL
        if (not $subs) {
            return $self->internal_error("Accessing");
        }
        ($gids, $subscriptions) = $self->_get_pauseid_subscription($user, $pauseid_str, $subs->{id});
    } else {
        ($gids, $subscriptions) = $self->_get_all_subscriptions($user);
    }

    my $t = $self->load_tmpl("mypan.tmpl",
        loop_context_vars => 1,
    );
    $t->param(subscriptions => $subscriptions);
    $t->param(gids     => $gids);
    $t->param(fullname => $user->{fullname});
    $t->param(title    => "Information about $username");

    $t->output;
}

sub _get_all_subscriptions {
    my ($self, $user) = @_;

    my @subscriptions;
    my $s = CPAN::Forum::DB::Subscriptions_all->find_one(uid => $user->{id}); # SQL
    $self->log->debug("all subscriptions " . ($s ? "found" : "not found"));
    push @subscriptions, {
        gid       => "_all",
        group     => "All",
        allposts  => $s ? $s->{allposts}  : '',
        starters  => $s ? $s->{starters}  : '',
        followups => $s ? $s->{followups} : '',
    };
    my $gids = "_all";

    my $it = CPAN::Forum::DB::Subscriptions_pauseid->find(uid => $user->{id}); # SQL
    foreach my $s (@$it) {
        $gids .= ",_" . $s->{pauseid}; 
        push @subscriptions, {
            gid       => "_" . $s->{pauseid},
            group     => $s->{pauseid_name},
            allposts  => $s->{allposts},
            starters  => $s->{starters},
            followups => $s->{followups},
        };
    }

    $it = CPAN::Forum::DB::Subscriptions->find(uid => $user->{id}); # SQL
    foreach my $s (@$it) {
        $gids .= ($gids ? "," : "") . $s->{gid};
        push @subscriptions, {
            gid       => $s->{gid},
            group     => $s->{group_name},
            allposts  => $s->{allposts},
            starters  => $s->{starters},
            followups => $s->{followups},
        };
    }
    return ($gids, \@subscriptions);
}

sub _get_module_subscription {
    my ($self, $user, $group_name, $group)  = @_;

    my @subscriptions;
    my $gid = $group->{id};
    my $gids = $group->{id};
    my ($s) = CPAN::Forum::DB::Subscriptions->find_one(uid => $user->{id}, gid => $gid); # SQL
    if ($s) {
        push @subscriptions, {
            gid       => $gid,
            group     => $group_name,
            allposts  => $s->{allposts},
            starters  => $s->{starters},
            followups => $s->{followups},
        };
    } else {
        push @subscriptions, {
            gid       => $gid,
            group     => $group_name,
            allposts  => 0,
            starters  => 0,
            followups => 0,
        };
    }
    return ($gids, \@subscriptions);
}

sub _get_pauseid_subscription {
    my ($self, $user, $pauseid_str, $pauseid_id)  = @_;

    my @subscriptions;
    my $gids = "_" . $pauseid_id;
    my ($s) = CPAN::Forum::DB::Subscriptions_pauseid->find_one(uid => $user->{id}, pauseid => $pauseid_id); # SQL
    if ($s) {
        push @subscriptions, {
            gid       => "_" . $pauseid_id,
            group     => $pauseid_str,
            allposts  => $s->{allposts},
            starters  => $s->{starters},
            followups => $s->{followups},
        };
    } else {
        push @subscriptions, {
            gid       => "_" . $pauseid_id,
            group     => $pauseid_str,
            allposts  => 0,
            starters  => 0,
            followups => 0,
        };
    }
    return ($gids, \@subscriptions);
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
    my $user = CPAN::Forum::DB::Users->info_by(username => $username); # SQL
    my $uid = $user->{id};

    foreach my $gid (@gids) {
        my ($on, $data) = $self->_get_subs($gid);
        $self->log->debug("Processing GID: '$gid'");

        if ($gid eq "_all") {
            $self->log->debug("Subscription_all: '$uid', '$on', " . Data::Dumper->Dump([$data], ['data']));
            CPAN::Forum::DB::Subscriptions_all->complex_update({uid => $uid}, $on, $data); # SQL
        } elsif ($gid =~ /^_(\d+)$/) {
            my $pauseid = $1;
            $self->log->debug("Subscription_pauseid: pauseid='$pauseid', uid='$uid', on='$on', " . Data::Dumper->Dump([$data], ['data']));
            CPAN::Forum::DB::Subscriptions_pauseid->complex_update({pauseid => $pauseid, uid => $uid}, $on, $data); # SQL
        } elsif ($gid =~ /^(\d+)$/) {
            CPAN::Forum::DB::Subscriptions->complex_update({gid => $gid, uid => $uid}, $on, $data); #SQL 
        } else {
            $self->log->error("Invalid gid: '$gid' provided in the gids entry of mypan");
            # shall we show an error page here?
        }
    }
    
    return $self->notes("mypanok");

=pod
    # I think we don't need to provide this
    # A user either comes from the page of a Module ( /dist/Module-Name) 
    # and then we already have the value.
    # There should be also a similar link on the /author/PAUSEID  page
    # to link to mypan/author/PAUSEID
    

    # name is the empty textbox to hold an arbitrary values 
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
        my $author = CPAN::Forum::DB::Authors->get_author_by_pauseid($pauseid); # SQL
        if ($author) {
            my $s = CPAN::Forum::DB::Subscriptions_pauseid->find_or_create({
                uid       => $uid,
                pauseid   => $author->{id},
            });
            $self->_update_subs($s, "_new");
        } else {
            return $self->notes("no_such_pauseid");
        }
    }
    elsif ($q->param("type") eq "distro") {
        my $name = $q->param("name");
        $name =~ s/::/-/g;  
        my $group = CPAN::Forum::DB::Groups->info_by(name => $name); # SQL
        if ($group) {
            my $s = CPAN::Forum::DB::Subscriptions->find_or_create({
                uid       => $uid,
                gid       => $group->{id},
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
=cut

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

sub _get_subs {
    my ($self, $gid) = @_;
    my $q = $self->query;

    my %data;
    my $on = 0;
    foreach my $type (qw(allposts starters followups)) {
        if (defined $q->param($type ."_$gid") and $q->param($type . "_$gid") eq "on") {
            $data{$type} = 1;
            $on++;
        } else {
            $data{$type} = 0;
        }
    }
    return ($on, \%data);
}


1;

