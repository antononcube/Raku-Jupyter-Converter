#!/usr/bin/env raku
use v6.d;

use lib <. lib>;
use Jupyter::Converter;
use JSON::Fast;

my $fileName = $*CWD ~ '/resources/demo.ipynb';
say $fileName.IO.f;

my $json = slurp($fileName);

my $md   = from-jupyter($json, to => 'Markdown');
my $html = from-jupyter($json, :to<HTML>);
my $pod  = from-jupyter($json, :to<POD6>);

# explicit fallback to Markdown via Whatever
my $also-md = from-jupyter($json, target => Whatever);

# with pre-decoded hash:
my %nb = from-json($json);
say from-jupyter(%nb, :to<markdown>);
