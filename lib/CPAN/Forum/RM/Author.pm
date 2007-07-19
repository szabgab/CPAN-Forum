package CPAN::Forum::RM::Author;
use strict;
use warnings;

=head2 author

List posts by module author (PAUSEID)

=cut

sub author {
    my ($self) = @_;
    my $q = $self->query;

    my $pauseid = ${$self->param("path_parameters")}[0] || '';
    $self->log->debug("show posts to modules of PAUSEID: '$pauseid'");

    my $t = $self->load_tmpl("authors.tmpl",
        loop_context_vars => 1,
        global_vars => 1,
    );
   
    $t->param(pauseid => $pauseid);
    $t->param(title => "CPAN Forum - $pauseid");

    my $author = CPAN::Forum::DB::Authors->get_author_by_pauseid($pauseid);
    if (not $author) {
        $self->log->warning("Invalid pauseid $pauseid called in $ENV{PATH_INFO}");
        return $self->internal_error(
                "",
                "no_such_pauseid",
        );
    }
    # TODO: simplify query!
    my @group_ids = map {$_->id}
                    CPAN::Forum::DB::Groups->search( pauseid => $author->{id} );
    $self->log->debug("Group IDs: @group_ids");
    my $page = $q->param('page') || 1;
    $self->_search_results($t, {where => {gid => \@group_ids}, page => $page});
    #$self->_subscriptions($t, $gr);
    $t->output;
}

1;

