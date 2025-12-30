use Jupyter::Converter::Actionish;

#----------------------------------------------------------------------
# Markdown actions
#----------------------------------------------------------------------

class Jupyter::Converter::Markdown
        does Jupyter::Converter::Actionish {

    has $.image-directory is rw = Whatever;

    method !render-notebook(%nb --> Str) {
        my @cells = |%nb<cells> // [];
        my $lang  = self!infer-language(%nb);

        my @out;
        for @cells.kv -> $idx, %cell {
            my $md = self!render-cell(%cell, :$lang, :$idx);
            @out.push($md) if $md.chars;
        }
        @out.join("\n\n");
    }

    method !render-cell(%cell, :$lang!, :$idx!) {
        my $type   = %cell<cell_type> // '';
        my @source = self!normalize-source(%cell<source> // '');

        given $type {
            when 'markdown' { @source.join("\n") }
            when 'code'     { self!render-code-cell(%cell, @source, :$lang, :$idx) }
            when 'raw'      { @source.join("") }
            default         { self!render-unknown-cell(%cell, @source, :$idx) }
        }
    }

    method !render-code-cell(%cell, @source, :$lang, :$idx) {
        my $header = "```$lang";
        my $body   = @source.join("");
        my $footer = "```";
        "$header\n$body\n$footer";
    }

    method !render-unknown-cell(%cell, @source, :$idx) {
        my $type = %cell<cell_type> // '<unknown>';
        my $body = @source.join("");
        "```unknown-cell-$type\n$body\n```";
    }
}