package CPAN::Forum::RM::Tags;
use strict;
use warnings;

sub tags {
    my ($self) = @_;

    my $t = $self->load_tmpl("tags.tmpl",
        loop_context_vars => 1,
        global_vars => 1,
    );
    my $tags = CPAN::Forum::DB::Tags->get_all_tags();
    $t->param(tags => $tags);
    return $t->output; 
}

1;


