
unit module Packed ;

use v6;
use experimental :pack;

use IO::Blob;

role CustomMarshaller is export 
{
    method marshal($value, Mu:D $object) {
        ...
    }
}

role CustomMarshallerCode does CustomMarshaller {
    has &.marshaller is rw;

    method marshal($value, Mu:D $object) {
        # the dot below is important otherwise it refers
        # to the accessor method
        self.marshaller.($value);
    }
}

role CustomMarshallerMethod does CustomMarshaller {
    has Str $.marshaller is rw;
    method marshal($value, Mu:D $type) {
        my $meth = self.marshaller;
        $value."$meth"();
    }
}

role CustomMarshallerString does CustomMarshaller {
    has Str $.format is rw;
    method marshal($value, Mu:D $type) {
        pack($!format, $value);
    }
}

role AttributeFilter does CustomMarshaller {}
role LocalFilter does AttributeFilter {}
role CentralFilter does AttributeFilter {}
role DataFilter does AttributeFilter {}

multi sub trait_mod:<is> (Attribute $attr, :&packed-by!) is export {
    $attr does CustomMarshallerCode;
    $attr.marshaller = &packed-by;
}

multi sub trait_mod:<is> (Attribute $attr, Str:D :$packed-by!) is export {
    $attr does CustomMarshallerMethod;
    $attr.marshaller = $packed-by;
}

multi sub trait_mod:<is> (Attribute $attr, Str:D :$packed-as!) is export {
    $attr does CustomMarshallerString;
    $attr.format = $packed-as;
}

multi trait_mod:<is>(Attribute $attr, :$local-hdr!) {
    $attr does LocalFilter;
}

multi trait_mod:<is>(Attribute $attr, :$central-hdr!) {
    $attr does CentralFilter;
}

multi trait_mod:<is>(Attribute $attr, :$data-hdr!) {
    $attr does DataFilter;
}

my %pack-fmt-le = (
        16 => 'v',
        32 => 'V',
        64 => 'VV';
        );

my %pack-fmt-be = (
        16 => 'n',
        32 => 'N',
        64 => 'NN';
        );

sub _template($type) returns Str {
    #return %lookup-be{ $value } // "C";
    my $template = do given $type
    {
        when int8 |uint8  { "C" }
        when int16|uint16 { "v" }
        when int32|uint32 { "V" }
        when int64|uint64 { "VV"}
        when Bool         { "C" }
        #when Blob         { "C*"}
        default           { "" }
    };
    
    say "TEMPLATE[$template]";
    return $template ;
}

my %template{Mu:U} = (int8) => 'C',
                     (int16) => 'v',
                     (int32) => 'V',
                     (int64) => 'VV';
my %size_template = 8 => 'C',
                    16 => 'v',
                    32 => 'V',
                    64 => 'VV';

sub size(Int $x)
{
    #return 0 unless $x.HOW.^can("nativesize") ;
    return 0 unless $x.^can("nativesize") ;
    say "native size " ~ $x.^nativesize ;
    $x.^nativesize ;
}


#multi sub _marshal(Int $value) returns Blob {
#    say "INT " ~  size($value) ;
#    return pack(%size_template{ size($value) }, $value ) ;
#}

multi sub _marshal(Cool $value) returns Blob {

    my $template = %template{$value.WHAT};
    say "TL " ~ $value.WHAT.^name;
    return pack($template, $value) ;
}

#    multi sub _marshal(Str $value, $type) returns Blob {
#
#        return _marshal($value.encode, Blob);
#    }

multi sub _marshal(%obj) returns Blob {
    my Blob $ret .= new ;
    my $type = %obj.WHAT;
    my %ret;

    for %obj.kv -> $key, $value {
        $ret ~=  _marshal($key.encode) ~  _marshal($value);
    }

    $ret;
}

multi sub _marshal(Blob \blob) returns Blob {
    say "BLOB";
    blob;
}

multi sub _marshal(@obj) returns Blob {
    my Blob $ret .= new ;

    my $type = @obj.WHAT;
    my $of = $type.of;
    my $template-of = %template{$of};
    if $template-of 
    {
        say $of.^name;
        say $template-of ~ @obj.elems;
        $ret ~= pack($template-of ~ @obj.elems, |@obj);
        say $ret;
    }   
    else
    {

        for @obj -> $item {
            $ret ~=  _marshal($item) ;
        }
    }
    $ret;
}

multi sub _marshal(Mu $obj) returns Blob {
    my Blob $ret .= new ;
    for $obj.^attributes -> $attr {

        next unless $attr.has_accessor;
        #next if $attr ~~ AttributeFilter and not $attr ~~ $filter;

        my $value = $attr.get_value($obj);
        my $type = $attr.type;
        my $template = %template{$type};
        say $attr.name;

        if $template 
        {
            if $template eq 'VV'
            {
                my $low = $value +& 0xFFFFFFFF;
                my $high = ($value +>32) +& 0xFFFFFFFF;
                $ret ~= pack('VV', $low, $high) ;
            }
            else
            {
                $ret ~= pack($template, $value) ;
            }
        }
        else {
            $ret ~= _marshal($value);
        }

    }
    $ret;
}

multi sub marshal(Any $obj) returns Blob is export 
{
    _marshal($obj);
}

#multi sub marshal(Any $obj, Mu $filter) returns Blob is export {
#    _marshal($obj, $filter);
#}
#
#sub marshal-local-hdr(Any $obj) returns Blob is export {
#    _marshal($obj, LocalFilter);
#}
#
#sub marshal-central-hdr(Any $obj) returns Blob is export {
#    _marshal($obj, CentralFilter);
#}
#
#sub marshal-data-hdr(Any $obj) returns Blob is export {
#    _marshal($obj, DataFilter);
#}

####################

#role Unpacker
{
    use experimental :pack;

    multi sub unpacker(Mu:U $class, Str $filename) is export
    {
        my $filehandle = open $filename, :r, :bin ;
        #self.bless(:$filehandle, filename => $filename.IO, |c);
        _unpack($class, $filehandle);
    }

    multi sub unpacker(Mu:U $class, IO::Path $filename) is export
    {
        my $filehandle = open $filename, :r, :bin ;
        _unpack($class, $filehandle);
    }

    multi sub unpacker(Mu:U $class, Blob $data) is export
    {
        my IO::Blob $filehandle .= new($data);
        _unpack($class, $filehandle);
    }

    my %sizes = C => 1,
                v => 2,
                V => 4,
                VV => 8 ;

    sub unpack_template($type) returns Str {
        #return %lookup-be{ $value } // "C";
        my $template = do given $type
        {
            when int8 |uint8  { "C" }
            when int16|uint16 { "v" }
            when int32|uint32 { "V" }
            when int64|uint64 { "VV"}
            when Bool         { "C" }
            default           { ""}
        };
        
        say "TEMPLATE[$template]";
        return $template ;
    }

#    multi sub _unpack(Cool $value, $type) 
#    {
#
#        my $template = _template($type);
#        return unpack($template, $value) ;
#    }

    #    multi sub _marshal(Str $value, $type) returns Blob {
    #
    #        return _marshal($value.encode, Blob);
    #    }


#    multi _unpack(@x, $fh) {
#        my @ret;
#        for $json.list -> $value {
#           my $type = @x.of =:= Any ?? $value.WHAT !! @x.of;
#           @ret.append(_unpack($value, $type));
#        }
#        return @ret;
#    }
#
#    multi _unpack(%x, $fh) {
#       my %ret;
#       for $json.kv -> $key, $value {
#          my $type = %x.of =:= Any ?? $value.WHAT !! %x.of;
#          %ret{$key} = _unpack($value, $type);
#       }
#       return %ret;
#    }

    multi sub _unpack(Any $class, $fh) {
        say "_unpack " ~ $class.^name ;
        my %args;
        my $new = $class.new;
        for $class.^attributes -> $attr {

            next unless $attr.has_accessor;

            my $attr-name = $attr.name.substr(2);
            say $attr-name ;
            #my $value = $attr.get_value($class);
            my $type = $attr.type;
            my $template = unpack_template($type);

            if $template 
            {
                my Blob $data = $fh.read(%sizes{$template});
                if $template eq 'VV'
                {
                    my ($low, $high) = $data.unpack($template);
                    $attr.set_value($new, ($high +< 32) + $low);
                }
                else
                {
                    $attr.set_value($new, $data.unpack($template));
                }
            }
            else
            {
                $attr.set_value($new, _unpack($type, $fh));
            }

#            %args{$attr-name} = do if $template {
#                my Blob $data = $fh.read(%sizes{$template});
#                $data.unpack($template);
#            }
#            else {
#                _unpack($type, $fh);
#            }
        }

        #return $class.new(|%args)
        return $new;
    }
}



# vim: expandtab shiftwidth=4 ft=perl6
