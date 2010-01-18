package CPAN::Forum::INC;
use strict;
use warnings;

our $VERSION = '0.18';

use CPAN::Forum::Markup;
use CPAN::Forum::DBI;

use CPAN::Forum::DB::Authors;
use CPAN::Forum::DB::Configure;
use CPAN::Forum::DB::Groups;
use CPAN::Forum::DB::Posts;
use CPAN::Forum::DB::Subscriptions_all;
use CPAN::Forum::DB::Subscriptions_pauseid;
use CPAN::Forum::DB::Subscriptions;
use CPAN::Forum::DB::Tags;
use CPAN::Forum::DB::Users;


1;

