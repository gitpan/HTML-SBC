use Test::Simple tests => 5;
use HTML::SBC qw(sbc_translate_inline);

my @tests = (
    {   title => 'plain text',
        trans => [ 'foo bar baz',
            qq(foo bar baz),
        ]
    }, {
        title => 'emphasis',
        trans => [ '*foo*',
            qq(<em>foo</em>),
        ]
    }, {
        title => 'strong emphasis',
        trans => [ '_foo_',
            qq(<strong>foo</strong>),
        ]
    }, {
        title => 'hyperlink',
        trans => [ '<http://foo>',
            qq(<a href="http://foo">http://foo</a>),
        ]
    }, {
        title => 'hyperlink with text',
        trans => [ '<http://foo bar>',
            qq(<a href="http://foo">bar</a>),
        ]
    },
);

foreach my $test (@tests) {
    ok(
        sbc_translate_inline($test->{trans}[0]) eq $test->{trans}[1],
        $test->{title}
    );
}
