use strict;
use warnings;

use Time::HiRes qw(sleep);
use Test::More;
use Test::Exception;

eval {require Test::WWW::Selenium };
if ($@) {
	plan skip_all => 'Need Test::WWW::Selenium';
} elsif (not $ENV{CPANFORUM_URL}) {
	plan skip_all => 'Need CPANFORUM_URL';
}

# "http://cgi.cpanforum.local/"

my $sel = Test::WWW::Selenium->new( host => "localhost", 
                                    port => 4444, 
                                    browser => "*chrome", 
                                    browser_url => $ENV{CPANFORUM_URL} );

$sel->open_ok("/");
$sel->click_ok("link=register");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("nickname", "qwerty");
$sel->type_ok("email", "szabgab\@gmail.com");
$sel->click_ok("//input[\@value='Register']");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("email", "gabor\@pti.co.il");
$sel->click_ok("//input[\@value='Register']");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("email", "gabor\@lael.co.il");
$sel->click_ok("//input[\@value='Register']");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=new post");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=home");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=login");
$sel->wait_for_page_to_load_ok("30000");
$sel->select_frame_ok("c19myk7svz3q8u");
$sel->click_ok("link=Inbox");
