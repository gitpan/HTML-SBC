use Test::Simple tests => 9;
use HTML::SBC qw(sbc_translate);

my @tests = (
    {   title => 'plain text',
        trans => [ 'foo bar baz',
            qq(<p>foo bar baz</p>\n),
        ]
    }, {
        title => 'emphasis',
        trans => [ '*foo*',
            qq(<p><em>foo</em></p>\n),
        ]
    }, {
        title => 'strong emphasis',
        trans => [ '_foo_',
            qq(<p><strong>foo</strong></p>\n),
        ]
    }, {
        title => 'hyperlink',
        trans => [ '<http://foo>',
            qq(<p><a href="http://foo">http://foo</a></p>\n),
        ]
    }, {
        title => 'hyperlink with text',
        trans => [ '<http://foo bar>',
            qq(<p><a href="http://foo">bar</a></p>\n),
        ]
    }, {
        title => 'unordered list',
        trans => [ qq(- foo\n- bar),
            qq(<ul>\n\t<li>foo</li>\n\t<li>bar</li>\n</ul>\n),
        ]
    }, {
        title => 'ordered list',
        trans => [ qq(# foo\n# bar),
            qq(<ol>\n\t<li>foo</li>\n\t<li>bar</li>\n</ol>\n),
        ]
    }, {
        title => 'quote',
        trans => [ qq([foo]),
            qq(<div class="quote"><blockquote>\n)
            . qq(<p>foo</p>\n</blockquote></div>\n),
        ]
    }, {
        title => 'quote with cite',
        trans => [ qq([foo]bar),
            qq(<div class="quote"><cite>bar</cite><blockquote>\n)
            . qq(<p>foo</p>\n</blockquote></div>\n),
        ]
    },
        
);

foreach my $test (@tests) {
    ok(
        sbc_translate($test->{trans}[0]) eq $test->{trans}[1],
        $test->{title}
    );
}
