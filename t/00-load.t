#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'HTML::SBC' );
}

diag( "Testing HTML::SBC $HTML::SBC::VERSION, Perl $], $^X" );
