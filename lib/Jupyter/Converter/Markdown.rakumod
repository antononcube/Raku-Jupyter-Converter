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

        my $svg-links = self!render-svg-outputs(%cell<outputs> // [], :$idx);
        @chunks.push($svg-links) if $svg-links.chars;

        @chunks.join("\n\n");
    }

    method !render-unknown-cell(%cell, @source, :$idx) {
        my $type = %cell<cell_type> // '<unknown>';
        my $body = @source.join("");
        "```unknown-cell-$type\n$body\n```";
    }

    method !render-svg-outputs(@outputs, :$idx! --> Str) {
        my @links;

        for @outputs.kv -> $output-idx, %output {
            my $data    = %output<data> // next;
            my $raw-svg = $data{'image/svg+xml'}
                       // self!extract-svg-from-html($data{'text/html'})
                       // next;

            my $svg = self!normalize-svg($raw-svg) // next;

            my $path = self!write-svg($svg, :cell-idx($idx), :$output-idx);
            if $!notebook-dirname.defined && $!notebook-dirname.Str eq $path.IO.dirname.Str {
                $path .= subst($!notebook-dirname, '.')
            }
            @links.push("![cell {$idx + 1} output {$output-idx + 1} svg]($path)");
        }

        @links.join("\n\n");
    }

    method !normalize-svg($raw) {
        given $raw {
            when Str        { return $raw }
            when Positional { return $raw.join("") }
            default         { return Nil }
        }
    }

    method !extract-svg-from-html($raw-html) {
        my $html = do given $raw-html {
            when Str        { $_ }
            when Positional { .join("") }
            default         { return Nil }
        }

        return Nil unless $html ~~ /:i '<svg'/;

        if $html ~~ /:s ( '<svg' .*? '</svg>' ) / {
            return ~$0;
        }
        return $html;
    }

    method !write-svg(Str $svg, :$cell-idx!, :$output-idx! --> Str) {
        my $dir = self!ensure-image-directory;

        my $file = "cell-{$cell-idx + 1}-output-{$output-idx + 1}.svg";

        my $path = $dir.add($file);
        spurt($path, $svg);
        $path.Str;
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
