unit module Jupyter::Converter;

use JSON::Fast;
use Jupyter::Converter::Markdown;
use Jupyter::Converter::HTML;
use Jupyter::Converter::POD6;

#----------------------------------------------------------------------
# Internal conversion dispatcher
#----------------------------------------------------------------------

sub convert-notebook(%nb,
                     :target(:$to) is copy = Whatever,
                     :$image-directory = Whatever
        --> Str) {

    if $to.isa(Whatever) { $to = 'Markdown' }
    die 'The argument $to is expected to be a string or Whatever.'
    unless $to ~~ Str:D;


    my $actions = do given $to.lc {
        when $_ ∈ <raku perl6> { %nb }
        when $_ eq 'markdown'  { Jupyter::Converter::Markdown.new(:$image-directory) }
        when $_ eq 'html'      { Jupyter::Converter::HTML.new }
        when $_ ∈ <pod6 pod>   { Jupyter::Converter::POD6.new }
        default {
            my @expected = <Markdown HTML POD6>;
            die "Unknown target spec. Target specification is expected to be one of: \"{@expected.join('", "')}\"."
        }
    }

    $actions.render-notebook(%nb);
}

#----------------------------------------------------------------------
# Public API: single exported sub
#----------------------------------------------------------------------

sub from-jupyter($notebook,
                 :target(:$to) is copy = Whatever,
                 :$image-directory is copy = Whatever
        --> Str) is export {

    if $notebook.IO.f {
        my $text = slurp($notebook);
        return from-jupyter($text, :$to);
    }

    if $image-directory.isa(Whatever) { $image-directory = $notebook.IO.dirname ~ '/img'}
    if $image-directory.IO.e && !$image-directory.IO.d {
        die "Cannot use '$image-directory' as directory."
    } elsif !$image-directory.IO.d {
        $image-directory.IO.mkdir
    }
    
    if $to.isa(Whatever) { $to = 'Markdown' }
    die 'The argument $to is expected to be a string or Whatever.'
    unless $to ~~ Str:D;

    my $nb;
    given $notebook {
        when $_ ~~ Associative:D { $nb = $_ }

        when $_ ~~ Str:D {
            try { $nb = from-json($_.trim) }
            if $! {
                die 'The first argument is not a valid JSON string.'
            }
            die 'The JSON string did not produce a hashmap.'
            unless $nb ~~ Map:D;
        }

        default {
          die 'The first argument is expected to be a JSON string or a hashmap.'
        }
    }

    return convert-notebook($nb, :$to, :$image-directory);
}
