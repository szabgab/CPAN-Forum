package CPAN::Forum::RM::Update;
use strict;
use warnings;

sub update {
    my ($self) = @_;

    my $q = $self->query;
    my $what = $q->param('what');
    if (defined $what and $what eq 'tags') {
        return $self->_update_tags;
    }
 
    
    return $self->internal_error();
}

sub _update_tags {
    my ($self) = @_;

    my $q = $self->query;
    my $group_id = $q->param('group_id');
    my $new_tags = $q->param('new_tags'); 
    $self->log->debug("_update_tags in group '$group_id' tags='$new_tags'");
    $new_tags =~ s/^\s+//;
    $new_tags =~ s/\s+$//;
    $new_tags =~ s{<>/}{};
    my @tags = split /,/, lc $new_tags;

    my $uid = $self->session->param('uid');

    # TODO: let the client side decide which tags need to be added and removed
    my $tags_hr = CPAN::Forum::DB::Tags->get_tags_hash_of($group_id, $uid);
    
    foreach my $tag (@tags) {
        if ($tags_hr->{$tag}) {
            delete $tags_hr->{$tag};
        } else { 
            CPAN::Forum::DB::Tags->attach_tag($uid, $group_id, $tag);
        }
    }
    foreach my $old_tag (keys %$tags_hr) {
        CPAN::Forum::DB::Tags->remove_tag($uid, $group_id, $tags_hr->{$old_tag});
    }

    return $self->notes('tags_updated');
}


1;


