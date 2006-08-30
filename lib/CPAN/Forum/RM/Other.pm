package CPAN::Forum::RM::Other;
use strict;
use warnings;


=head2 about

About box with some statistics.

=cut

sub about {
    my $self = shift;
    my $t = $self->load_tmpl("about.tmpl");
    
    $t->param(distro_cnt        => CPAN::Forum::DB::Groups->count_all());
    $t->param(posts_cnt         => CPAN::Forum::DB::Posts->count_all());
    $t->param(users_cnt         => CPAN::Forum::DB::Users->count_all());
    $t->param(subscription_cnt  => CPAN::Forum::DB::Subscriptions->count_all());
    $t->param(version           => $self->version);
    # number of posts per group name, can create some xml feed from it that can
    # be used by search.cpan.org and Kobes to add a number of posts next to the link
    #select count(*),groups.name from posts, groups where groups.id=gid group by gid;
    #
    #count posts for a specific group:
    #select count(*) from posts, groups where groups.id=gid and groups.name="CPAN-Forum";

    $t->output;
}

=head2 stats

The stats run-mode showing some statistics
(actually the 50 busiest groups)

=cut

sub stats {
    my $self = shift;
    my $t = $self->load_tmpl("stats.tmpl");
    my @entries = CPAN::Forum::DB::Posts->search_stat_posts(50);
    
    $t->param(entries => \@entries);
    $t->output;
}

sub faq {
    my $self = shift;
    my $t = $self->load_tmpl("faq.tmpl");
    $t->output;
}

1;

