package CPAN::Forum::RM::Tags;
use strict;
use warnings;

sub tags {
    my ($self) = @_;

    my $path = ${$self->param("path_parameters")}[0] || '';
    my $value = ${$self->param("path_parameters")}[1] || '';
    $self->log->debug("tags path='$path' value='$value'");
    if ($path eq 'name' and $value) {
        return $self->_list_modules_with_tag($value);
    }
     

    my $t = $self->load_tmpl("tags.tmpl",
        loop_context_vars => 1,
        global_vars => 1,
    );
    my $tags = CPAN::Forum::DB::Tags->get_all_tags();
    $t->param(tags => $tags);
    return $t->output; 
}

sub _list_modules_with_tag {
    my ($self, $value) = @_;

    my $t = $self->load_tmpl("modules_with_tags.tmpl",
        loop_context_vars => 1,
        global_vars => 1,
    );
    my $modules = CPAN::Forum::DB::Tags->get_modules_with_tag($value);
    $t->param(tag => $value);
    $t->param(modules => $modules);
    return $t->output; 
    
}

1;


