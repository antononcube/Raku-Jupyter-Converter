use v6.d;

#----------------------------------------------------------------------
# Common infrastructure
#----------------------------------------------------------------------

role Jupyter::Converter::Actionish {
    method render-notebook(%notebook --> Str) {
        self!ensure-notebook(%notebook);
        self!render-notebook(%notebook);
    }

    method !ensure-notebook(%nb) {
        die "Notebook hash must have a <cells> array"
        unless %nb<cells>:exists && %nb<cells>.isa(List);
    }

    method !render-notebook(%notebook --> Str) {
        X::NYI.new(
                feature => 'render-notebook in ' ~ self.^name
                ).throw;
    }

    method !normalize-source($s) {
        return do given $s {
            when Array { $s.map(*.Str) }
            default    { $s.Str.lines   }
        }
    }

    method !infer-language(%nb) {
        with %nb<metadata><language_info><name> -> $n {
            return $n if $n.defined && $n.chars;
        }
        with %nb<metadata><kernelspec><language> -> $k-lang {
            return $k-lang if $k-lang.defined && $k-lang.chars;
        }
        with %nb<metadata><kernelspec><name> -> $k-name {
            return $k-name if $k-name.defined && $k-name.chars;
        }
        return 'python'
    }
}

class X::Jupyter::Converter::DecodeError is Exception {
    has Str:D $.json;
    has Str:D $.message;

    method message() {
        "Failed to decode Jupyter notebook JSON: $.message"
    }
}

class X::Jupyter::Converter::StructureError is Exception {
    has Str:D $.message;
    method message() { "Invalid Jupyter notebook structure: $.message" }
}