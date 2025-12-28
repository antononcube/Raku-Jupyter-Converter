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
    has Str $.json;
    has Str $.message;

    method message() {
        "Failed to decode Jupyter notebook JSON: $.message"
    }
}

class X::Jupyter::Converter::StructureError is Exception {
    has Str $.message;
    method message() { "Invalid Jupyter notebook structure: $.message" }
}

#----------------------------------------------------------------------
# Facade class (optional to use)
#----------------------------------------------------------------------
#`[
class Jupyter::Converter {
    has %.nb;

    multi method new(:%nb! ) {
        self.bless(:%nb);
    }

    multi method new(:$json! ) {
        my %nb;
        try {
            %nb = from-json($json);
            CATCH {
                default {
                    X::Jupyter::Converter::DecodeError.new(
                            json    => '[snipped JSON; too long to show]',
                            message => .message
                            ).throw;
                }
            }
        }
        X::Jupyter::Converter::StructureError.new(
                message => 'Top-level notebook must be an Associative (Hash)'
                ).throw unless %nb ~~ Associative;

        self.bless(:%nb);
    }

    method convert(:to(:$target) = Whatever --> Str) {
        convert-notebook(%!nb, :$target);
    }
}
]