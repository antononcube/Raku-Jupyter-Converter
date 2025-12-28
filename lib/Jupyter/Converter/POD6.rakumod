
use Jupyter::Converter::Actionish;

#----------------------------------------------------------------------
# POD6 actions
#----------------------------------------------------------------------

class Jupyter::Converter::POD6
        does Jupyter::Converter::Actionish {

    method !render-notebook(%nb --> Str) {
        my @cells = |%nb<cells> // [];
        my $lang  = self!infer-language(%nb);

        my @out;
        @out.push("=begin pod");
        @out.push("");

        for @cells.kv -> $idx, %cell {
            my $pod = self!render-cell(%cell, :$lang, :$idx);
            @out.push($pod) if $pod.chars;
            @out.push("");
        }

        @out.push("=end pod");
        @out.join("\n");
    }

    method !render-cell(%cell, :$lang!, :$idx!) {
        my $type   = %cell<cell_type> // '';
        my @source = self!normalize-source(%cell<source> // '');

        given $type {
            when 'markdown' { @source.join("\n") }
            when 'code'     { self!render-code-cell(%cell, @source, :$lang, :$idx) }
            when 'raw'      { self!render-raw-cell(@source, :$idx) }
            default         { self!render-unknown-cell(%cell, @source, :$idx) }
        }
    }

    method !render-code-cell(%cell, @source, :$lang, :$idx) {
        my $body = @source.join("");
        qq:to/POD/;
=begin code :lang<$lang>
$body
=end code
POD
    }

    method !render-raw-cell(@source, :$idx) {
        my $body = @source.join("");
        qq:to/POD/;
=begin raw
$body
=end raw
POD
    }

    method !render-unknown-cell(%cell, @source, :$idx) {
        my $type = %cell<cell_type> // '<unknown>';
        my $body = @source.join("");
        qq:to/POD/;
=begin code :lang<unknown-$type>
$body
=end code
POD
    }
}