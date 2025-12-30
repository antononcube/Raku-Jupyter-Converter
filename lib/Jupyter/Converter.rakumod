unit module Jupyter::Converter;

use JSON::Fast;
use Jupyter::Converter::Markdown;
use Jupyter::Converter::HTML;
use Jupyter::Converter::POD6;
use Markdown::Grammar;

#----------------------------------------------------------------------
# Internal conversion dispatcher
#----------------------------------------------------------------------

sub convert-notebook(%nb,
                     :target(:$to) is copy = Whatever,
                     :$image-dirname = Whatever,
                     :$notebook-dirname = Whatever,
                     :$method = Whatever
        --> Str) {

    if $to.isa(Whatever) { $to = 'Markdown' }
    die 'The argument $to is expected to be a string or Whatever.'
    unless $to ~~ Str:D;

    my Bool:D $delegate = $method ~~ Str:D && $method.lc ∈ <delegate delegation via-markdown>;

    return do given $to.lc {
        when $_ ∈ <raku perl6> { %nb }

        when $_ eq 'markdown' {
            Jupyter::Converter::Markdown.new(:$image-dirname, :$notebook-dirname).render-notebook(%nb)
        }

        when $_ eq 'html' && $delegate {
            my $md = from-jupyter(%nb, to => 'markdown', :$image-dirname, :$notebook-dirname);
            from-markdown($md, to => 'html')
        }

        when $_ eq 'html' {
            Jupyter::Converter::HTML.new.render-notebook(%nb)
        }

        when $_ ∈ <pod6 pod> && $delegate {
            my $md = from-jupyter(%nb, to => 'markdown', :$image-dirname, :$notebook-dirname);
            return from-markdown($md, to => 'pod6')
        }
        when $_ ∈ <pod6 pod> {
            Jupyter::Converter::POD6.new.render-notebook(%nb)
        }

        when $_ ∈ <org org-mode> {
            my $md = from-jupyter(%nb, to => 'markdown', :$image-dirname, :$notebook-dirname);
            return from-markdown($md, to => 'org-mode')
        }

        when $_ ∈ <wolfram wl mathematica> {
            my $md = from-jupyter(%nb, to => 'markdown', :$image-dirname, :$notebook-dirname);
            return from-markdown($md, to => 'mathematica')
        }

        default {
            my @expected = <Markdown Mathematica HTML POD6 Org-mode>;
            die "Unknown target spec. Target specification is expected to be one of: \"{@expected.join('", "')}\"."
        }
    }
}

#----------------------------------------------------------------------
# Public API: single exported sub
#----------------------------------------------------------------------

sub from-jupyter($notebook,
                 :target(:$to) is copy = Whatever,
                 :image-directory(:$image-dirname) is copy = Whatever,
                 :notebook-directory(:$notebook-dirname) is copy = Whatever,
                 :$method = Whatever
        --> Str) is export {

    if $notebook ~~ Str:D && $notebook.IO.f {
        if $image-dirname.isa(Whatever) { $image-dirname = $notebook.IO.dirname.Str ~ '/img' }
        $notebook-dirname = $notebook.IO.dirname.Str;
        my $text = slurp($notebook);
        return from-jupyter($text, :$to, :$image-dirname, :$notebook-dirname, :$method);
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

    die 'The argument $method is expected to be a string or Whatever.'
    unless $method.isa(Whatever) || $method ~~ Str:D;

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

    return convert-notebook($nb, :$to, :$image-dirname, :$notebook-dirname, :$method);
}
