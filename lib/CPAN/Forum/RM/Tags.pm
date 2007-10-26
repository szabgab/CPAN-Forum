package CPAN::Forum::RM::Tags;
use strict;
use warnings;

sub tags {
    my ($self) = @_;

    my $path = ${$self->param("path_parameters")}[0] || '';
    my $value = ${$self->param("path_parameters")}[1] || '';

    # support tag tcp/ip  but not a/b/c
    if (${$self->param("path_parameters")}[2]) {
        $value .= "/" . ${$self->param("path_parameters")}[2];
    }

    $self->log->debug("tags path='$path' value='$value'");
    if ($path eq 'name' and $value) {
        return $self->_list_modules_with_tag($value);
    } elsif ($path eq 'name_popup') {
        return $self->_list_modules_with_tag($value, 'popup/');
    } elsif ($path eq 'user' and $value) {
        my $tags = CPAN::Forum::DB::Tags->get_tags_of_user($value); # SQL
        return $self->_list_tags($tags, {user_name => $value});
    } else {
        my $tags = CPAN::Forum::DB::Tags->get_all_tags(); # SQL
        return $self->_list_tags($tags);
    }
}

sub _list_tags {
    my ($self, $tags, $params) = @_;

    my $t = $self->load_tmpl("tags.tmpl",
        loop_context_vars => 1,
        global_vars => 1,
    );

    my $tag_count = 0;
    # maximize tag size to 24
    foreach my $t (@$tags) {
        #$tag_count += $t->{total};
        $t->{total} = 24 if $t->{total} > 24;
    }
   
    $t->param(tags => $tags);
    #$t->param(tag_count => $tag_count);
    if ($params) {
        $t->param(%$params);
    }
    return $t->output; 
}

sub _list_modules_with_tag {
    my ($self, $value, $type) = @_;
    $type ||= '';

    my $t = $self->load_tmpl("${type}modules_with_tags.tmpl",
        loop_context_vars => 1,
        global_vars => 1,
    );
    my $modules = CPAN::Forum::DB::Tags->get_modules_with_tag($value); # SQL
    $t->param(tag => $value);
    $t->param(modules => $modules);
    return $t->output; 
}

1;


