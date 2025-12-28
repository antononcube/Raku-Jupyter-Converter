use v6.d;

use Jupyter::Converter::Actionish;

#----------------------------------------------------------------------
# HTML actions
#----------------------------------------------------------------------

class Jupyter::Converter::HTML
        does Jupyter::Converter::Actionish {

    method !render-notebook(%nb --> Str) {
        my @cells = |%nb<cells> // [];
        my $lang  = self!infer-language(%nb);

        my @chunks;
        @chunks.push('<!DOCTYPE html>');
        @chunks.push('<html>');
        @chunks.push('<head><meta charset="utf-8"><title>Notebook</title></head>');
        @chunks.push('<body>');

        for @cells.kv -> $idx, %cell {
            my $html = self!render-cell(%cell, :$lang, :$idx);
            @chunks.push($html) if $html.chars;
        }

        @chunks.push('</body>');
        @chunks.push('</html>');
        @chunks.join("\n");
    }

    method !render-cell(%cell, :$lang!, :$idx!) {
        my $type   = %cell<cell_type> // '';
        my @source = self!normalize-source(%cell<source> // '');

        given $type {
            when 'markdown' { self!render-markdown-cell(@source, :$idx) }
            when 'code'     { self!render-code-cell(%cell, @source, :$lang, :$idx) }
            when 'raw'      { self!render-raw-cell(@source, :$idx) }
            default         { self!render-unknown-cell(%cell, @source, :$idx) }
        }
    }

    method !render-markdown-cell(@source, :$idx) {
        my @lines = @source;
        my @paras;
        my @buffer;

        for @lines {
            if .trim.chars {
                @buffer.push($_);
            }
            else {
                if @buffer {
                    @paras.push(@buffer.join(" "));
                    @buffer = ();
                }
            }
        }
        @paras.push(@buffer.join(" ")) if @buffer;

        @paras.map({ '<p>' ~ self!escape-html($_) ~ '</p>' }).join("\n");
    }

    method !render-code-cell(%cell, @source, :$lang, :$idx) {
        my $code = @source.join("");
        my $esc  = self!escape-html($code);
        qq:to/HTML/;
<pre><code class="language-$lang">
$esc
</code></pre>
HTML
    }

    method !render-raw-cell(@source, :$idx) {
        my $txt = @source.join("");
        '<pre>' ~ self!escape-html($txt) ~ '</pre>';
    }

    method !render-unknown-cell(%cell, @source, :$idx) {
        my $type = %cell<cell_type> // '<unknown>';
        my $txt  = @source.join("");
        my $esc  = self!escape-html($txt);
        qq:to/HTML/;
<pre><code class="unknown-cell-$type">
$esc
</code></pre>
HTML
    }

    method !escape-html(Str $s --> Str) {
        $s.trans(
                '&' => '&amp;',
                '<' => '&lt;',
                '>' => '&gt;',
                '"' => '&quot;',
                "'" => '&#39;',
                );
    }
}
