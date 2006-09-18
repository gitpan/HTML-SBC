use Test::Simple tests => 6;
use HTML::SBC qw(sbc_translate);

my @tests = (
    {
        title => 'half emphasis',
        trans => [ qq(foo*bar),
            qq(<p>foo<em>bar</em></p>\n),
        ],
    }, {
        title => 'half strong emphasis',
        trans => [ qq(foo_bar),
            qq(<p>foo<strong>bar</strong></p>\n),
        ],
    }, {
        title => 'half hyperlink',
        trans => [ qq(foo<http://foo),
            qq(<p>foo<a href="http://foo">http://foo</a></p>\n),
        ],
    }, {
        title => 'half hyperlink with text',
        trans => [ qq(foo<http://foo bar),
            qq(<p>foo<a href="http://foo">bar</a></p>\n),
        ],
    }, {
        title => 'wrong nested inline elements  I',
        trans => [ qq(_foo*bar_baz*yada),
            qq(<p><strong>foo<em>bar</em></strong>baz<em>yada</em></p>\n),
        ]
    }, {
        title => 'wrong nested inline elements II',
        trans => [ qq(<http://foo foo_bar>),
            qq(<p><a href="http://foo">foo<strong>bar</strong></a></p>\n),
        ]
    },
);

foreach my $test (@tests) {
    ok(
        sbc_translate($test->{trans}[0]) eq $test->{trans}[1],
        $test->{title}
    );
}
