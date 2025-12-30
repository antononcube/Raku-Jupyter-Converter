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
                     :$image-dirname = Whatever,
                     :$notebook-dirname = Whatever,
        --> Str) {

    if $to.isa(Whatever) { $to = 'Markdown' }
    die 'The argument $to is expected to be a string or Whatever.'
    unless $to ~~ Str:D;

    say (:$image-dirname, :$notebook-dirname);
    my $actions = do given $to.lc {
        when $_ ∈ <raku perl6> { %nb }
        when $_ eq 'markdown'  { Jupyter::Converter::Markdown.new(:$image-dirname, :$notebook-dirname) }
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
                 :$image-dirname is copy = Whatever,
                 :$notebook-dirname is copy = Whatever,
        --> Str) is export {

    if $notebook.IO.f {
        if $image-dirname.isa(Whatever) { $image-dirname = $notebook.IO.dirname.Str ~ '/img' }
        $notebook-dirname = $notebook.IO.dirname.Str;
        my $text = slurp($notebook);
        return from-jupyter($text, :$to, :$image-dirname, :$notebook-dirname);
    }

    if $image-dirname.isa(Whatever) { $image-dirname = $*CWD ~ '/img' }
    if $notebook-dirname.isa(Whatever) { $notebook-dirname = $*CWD }
    if $image-dirname.IO.e && !$image-dirname.IO.d {
        die "Cannot use '$image-dirname' as directory."
    } elsif !$image-dirname.IO.d {
        $image-dirname.IO.mkdir
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

    return convert-notebook($nb, :$to, :$image-dirname, :$notebook-dirname);
}
