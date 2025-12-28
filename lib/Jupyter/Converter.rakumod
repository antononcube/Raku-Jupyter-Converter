unit module Jupyter::Converter;

use JSON::Fast;
use Jupyter::Converter::Markdown;
use Jupyter::Converter::HTML;
use Jupyter::Converter::POD6;

#----------------------------------------------------------------------
# Internal conversion dispatcher
#----------------------------------------------------------------------

sub convert-notebook(%nb, :to(:$target) is copy = Whatever --> Str) {

    if $target.isa(Whatever) { $target = 'Markdown' }
    die 'The argument $target is expected to be a string or Whatever.'
    unless $target ~~ Str:D;


    my $actions = do given $target.lc {
        when $_ eq 'markdown' { Jupyter::Converter::Markdown.new }
        when $_ eq 'html'     { Jupyter::Converter::HTML.new }
        when $_ ∈ <pod6 pod>  { Jupyter::Converter::POD6.new }
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

sub from-jupyter($notebook, :to(:$target) is copy = Whatever --> Str) is export {

    if $target.isa(Whatever) { $target = 'Markdown' }
    die 'The argument $target is expected to be a string or Whatever.'
    unless $target ~~ Str:D;

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

    return convert-notebook($nb, :$target);
}
