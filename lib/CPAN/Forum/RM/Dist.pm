package CPAN::Forum::RM::Dist;
use strict;
use warnings;

=head2 dist

List last few posts belonging to this group, provides a link to post a new 
message within this group

=cut

sub dist {
    my ($self) = @_;
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

    my $t = $self->load_tmpl("groups.tmpl",
        loop_context_vars => 1,
        global_vars => 1,
    );
    $t->param(hide_group => 1);
                
    $t->param(group => $group_name);
    $t->param(title => "CPAN Forum - $group_name");

    my ($gr) = CPAN::Forum::DB::Groups->search(name => $group_name);
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

    # TODO: is is not clear to me how can here anything be undef, but I got
    # several exceptions on eith $gr or $gr->pauseid being undef:
    if ($gr and  $gr->pauseid and $gr->pauseid->pauseid) {
        $t->param(pauseid_name => $gr->pauseid->pauseid);
    }

    my $uid = $self->session->param('uid');
    if ($uid) {
        my $tags = CPAN::Forum::DB::Tags->get_tags_of($gid, $uid);
        $t->param(tags      => $tags);
        $t->param(show_tags => 1);
    }
    $t->param(group_id => $gid);

    return $t->output;
}

1;

