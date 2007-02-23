use strict;
use warnings;
use Test::Simple tests => 6;
use HTML::SBC;

ok(
    HTML::SBC->quote('foo') eq "[\nfoo\n]\n",
    'simple quote'
);

ok(
    HTML::SBC->quote('foo', 'bar') eq "[\nfoo\n]bar\n",
    'quote with cite'
);

ok(
    HTML::SBC->remove_hyperlinks('foo <http://bar> baz')
        eq 'foo http://bar baz',
    'remove simple hyperlink'
);

ok(
    HTML::SBC->remove_hyperlinks('foo <http://bar baz> quux')
        eq 'foo baz quux',
    'remove hyperlink with text'
);

ok(
    HTML::SBC->remove_hyperlinks('foo {http://bar} baz')
        eq 'foo  baz',
    'remove hyperlink (simple image)'
);

ok(
    HTML::SBC->remove_hyperlinks('foo {http://bar baz} quux')
        eq 'foo baz quux',
    'remove hyperlink (image with alt text)'
);

__END__
