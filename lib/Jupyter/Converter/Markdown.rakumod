use Jupyter::Converter::Actionish;

#----------------------------------------------------------------------
# Markdown actions
#----------------------------------------------------------------------

class Jupyter::Converter::Markdown
        does Jupyter::Converter::Actionish {

    has $.image-dirname is rw = Whatever;
    has $.notebook-dirname is rw = Whatever;

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
            when 'markdown' { @source.join }
            when 'code'     { self!render-code-cell(%cell, @source, :$lang, :$idx) }
            when 'raw'      { @source.join("") }
            default         { self!render-unknown-cell(%cell, @source, :$idx) }
        }
    }

    method !render-code-cell(%cell, @source, :$lang, :$idx) {
        my $header = "```$lang";
        my $body   = @source.join("");
        my $footer = "```";
        my @chunks = "$header\n$body\n$footer";

        my $rendered-outputs = self!render-outputs(%cell<outputs> // [], :$idx);
        @chunks.push($rendered-outputs) if $rendered-outputs.chars;

        @chunks.join("\n\n");
    }

    method !render-unknown-cell(%cell, @source, :$idx) {
        my $type = %cell<cell_type> // '<unknown>';
        my $body = @source.join("");
        "```unknown-cell-$type\n$body\n```";
    }

    method !render-outputs(@outputs, :$idx! --> Str) {
        my @chunks;

        for @outputs.kv -> $output-idx, %output {
            if %output<text> -> $raw-text {
                @chunks.push("```\n{( '# ' <<~<< $raw-text).join}\n```");
            }

            my $data = %output<data> // next;

            if $data<text/html> -> $raw-html {
                my $html = self!render-html-output($raw-html, :cell-idx($idx), :$output-idx);
                @chunks.push($html) if $html.chars;
            }

            if $data<image/svg+xml> -> $raw-svg {
                my $svg = self!normalize-svg($raw-svg) // next;

                my $path = self!write-svg($svg, :cell-idx($idx), :$output-idx);
                @chunks.push("![cell {$idx + 1} output {$output-idx + 1} svg]($path)");
            }

            if ($data<text/plain> // $data<text>) -> $raw-text {
                @chunks.push("```\n{( '# ' X~ $raw-text).join}\n```");
            }
        }

        @chunks.join("\n\n");
    }

    method !normalize-svg($raw) {
        given $raw {
            when Str        { return $raw }
            when Positional { return $raw.join("") }
            default         { return Nil }
        }
    }

    method !render-html-output($raw-html, :$cell-idx!, :$output-idx! --> Str) {
        my $html = do given $raw-html {
            when Str        { $_ }
            when Positional { .join("") }
            default         { return Nil }
        }

        my $svg-idx = 0;
        my $cell-num   = $cell-idx   + 1;
        my $output-num = $output-idx + 1;

        $html = $html.subst(
            /:s '<svg' .*? '</svg>' /,
            {
                my $svg = ~$/;
                my $path = self!write-svg($svg, :$cell-idx, :$output-idx, :svg-idx($svg-idx));
                $svg-idx++;
                qq{<img src="$path" alt="cell $cell-num output $output-num svg $svg-idx">};
            },
            :g
        ) if $html ~~ /:i '<svg'/;

        $html;
    }

    method !write-svg(Str $svg, :$cell-idx!, :$output-idx!, :$svg-idx = 0 --> Str) {
        my $dir = self!ensure-image-directory;

        my $file = "cell-{$cell-idx + 1}-output-{$output-idx + 1}";
        $file ~= "-{$svg-idx + 1}" if $svg-idx > 0;
        $file ~= ".svg";

        my $path = $dir.add($file);
        spurt($path, $svg);
        my $path-str = $path.Str;
        if $!notebook-dirname.defined && $!notebook-dirname.Str eq $path.IO.dirname.Str {
            $path-str .= subst($!notebook-dirname.Str, '.');
        }
        $path-str;
    }

    method !ensure-image-directory() {
        my $dir = $!image-dirname;
        if $dir.isa(Whatever) {
            $dir = 'img';
            $!image-dirname = $dir;
        }

        my $io = $dir.IO;
        if $io.e && !$io.d {
            die "Cannot use '$dir' as directory.";
        } elsif !$io.d {
            $io.mkdir;
        }

        $io;
    }
}
