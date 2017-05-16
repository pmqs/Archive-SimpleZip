unit module Archive::SimpleZip::Extra;

use v6;
use experimental :pack;

constant GZIP_FEXTRA_HEADER_SIZE          => 2 ;
constant GZIP_FEXTRA_MAX_SIZE             => 0xFFFF ;

constant GZIP_FEXTRA_SUBFIELD_ID_SIZE     => 2 ;
constant GZIP_FEXTRA_SUBFIELD_LEN_SIZE    => 2 ;
constant GZIP_FEXTRA_SUBFIELD_HEADER_SIZE => GZIP_FEXTRA_SUBFIELD_ID_SIZE +
                                                 GZIP_FEXTRA_SUBFIELD_LEN_SIZE;
constant GZIP_FEXTRA_SUBFIELD_MAX_SIZE    => GZIP_FEXTRA_MAX_SIZE - 
                                                 GZIP_FEXTRA_SUBFIELD_HEADER_SIZE ;


sub ExtraFieldError
{
    return $_[0];
    return "Error with ExtraField Parameter: $_[0]" ;
}

sub validateExtraFieldPair
{
    my $pair = shift ;
    my $strict = shift;
    my $gzipMode = shift ;

    return ExtraFieldError("Not an array ref")
        unless ref $pair &&  ref $pair eq 'ARRAY';

    return ExtraFieldError("SubField must have two parts")
        unless @$pair == 2 ;

    return ExtraFieldError("SubField ID is a reference")
        if ref $pair->[0] ;

    return ExtraFieldError("SubField Data is a reference")
        if ref $pair->[1] ;

    # ID is exactly two chars   
    return ExtraFieldError("SubField ID not two chars long")
        unless length $pair->[0] == GZIP_FEXTRA_SUBFIELD_ID_SIZE ;

    # Check that the 2nd byte of the ID isn't 0    
    return ExtraFieldError("SubField ID 2nd byte is 0x00")
        if $strict && $gzipMode && substr($pair->[0], 1, 1) eq "\x00" ;

    return ExtraFieldError("SubField Data too long")
        if length $pair->[1] > GZIP_FEXTRA_SUBFIELD_MAX_SIZE ;


    return undef ;
}

sub parseRawExtra
{
    my $data     = shift ;
    my $extraRef = shift;
    my $strict   = shift;
    my $gzipMode = shift ;

    #my $lax = shift ;

    #return undef
    #    if $lax ;

    my $XLEN = length $data ;

    return ExtraFieldError("Too Large")
        if $XLEN > GZIP_FEXTRA_MAX_SIZE;

    my $offset = 0 ;
    while ($offset < $XLEN) {

        return ExtraFieldError("Truncated in FEXTRA Body Section")
            if $offset + GZIP_FEXTRA_SUBFIELD_HEADER_SIZE  > $XLEN ;

        my $id = substr($data, $offset, GZIP_FEXTRA_SUBFIELD_ID_SIZE);    
        $offset += GZIP_FEXTRA_SUBFIELD_ID_SIZE;

        my $subLen =  unpack("v", substr($data, $offset,
                                            GZIP_FEXTRA_SUBFIELD_LEN_SIZE));
        $offset += GZIP_FEXTRA_SUBFIELD_LEN_SIZE ;

        return ExtraFieldError("Truncated in FEXTRA Body Section")
            if $offset + $subLen > $XLEN ;

        my $bad = validateExtraFieldPair( [$id, 
                                           substr($data, $offset, $subLen)], 
                                           $strict, $gzipMode );
        return $bad if $bad ;
        push @$extraRef, [$id => substr($data, $offset, $subLen)]
            if defined $extraRef;;

        $offset += $subLen ;
    }

        
    return undef ;
}

sub findID
{
    my $id_want = shift ;
    my $data    = shift;

    my $XLEN = length $data ;

    my $offset = 0 ;
    while ($offset < $XLEN) {

        return undef
            if $offset + GZIP_FEXTRA_SUBFIELD_HEADER_SIZE  > $XLEN ;

        my $id = substr($data, $offset, GZIP_FEXTRA_SUBFIELD_ID_SIZE);    
        $offset += GZIP_FEXTRA_SUBFIELD_ID_SIZE;

        my $subLen =  unpack("v", substr($data, $offset,
                                            GZIP_FEXTRA_SUBFIELD_LEN_SIZE));
        $offset += GZIP_FEXTRA_SUBFIELD_LEN_SIZE ;

        return undef
            if $offset + $subLen > $XLEN ;

        return substr($data, $offset, $subLen)
            if $id eq $id_want ;

        $offset += $subLen ;
    }
        
    return undef ;
}

# Extra Field ID's
constant ZIP_EXTRA_ID_ZIP64                => pack "v", 1;
constant ZIP_EXTRA_ID_EXT_TIMESTAMP        => "UT";
constant ZIP_EXTRA_ID_INFO_ZIP_UNIX2       => "Ux";
constant ZIP_EXTRA_ID_INFO_ZIP_UNIXN       => "ux";
constant ZIP_EXTRA_ID_INFO_ZIP_Upath       => "up";
constant ZIP_EXTRA_ID_INFO_ZIP_Ucom        => "uc";
constant ZIP_EXTRA_ID_JAVA_EXE             => pack "v", 0xCAFE;

sub mkSubField(Blob id, Blob $data)
{
    return $id ~ pack("v", $data.elems) ~ $data ;
}

sub mkExtraField-Zip64()
{
#   4.5.3 -Zip64 Extended Information Extra Field (0x0001):
# 
#      The following is the layout of the zip64 extended 
#      information "extra" block. If one of the size or
#      offset fields in the Local or Central directory
#      record is too small to hold the required data,
#      a Zip64 extended information record is created.
#      The order of the fields in the zip64 extended 
#      information record is fixed, but the fields MUST
#      only appear if the corresponding Local or Central
#      directory record field is set to 0xFFFF or 0xFFFFFFFF.
# 
#      Note: all fields stored in Intel low-byte/high-byte order.
# 
#        Value      Size       Description
#        -----      ----       -----------
#(ZIP64) 0x0001     2 bytes    Tag for this "extra" block type
#        Size       2 bytes    Size of this "extra" block
#        Original 
#        Size       8 bytes    Original uncompressed file size
#        Compressed
#        Size       8 bytes    Size of compressed data
#        Relative Header
#        Offset     8 bytes    Offset of local header record
#        Disk Start
#        Number     4 bytes    Number of the disk on which
#                              this file starts 
# 
#      This entry in the Local header MUST include BOTH original
#      and compressed file size fields. If encrypting the 
#      central directory and bit 13 of the general purpose bit
#      flag is set indicating masking, the value stored in the
#
#      Local Header for the original file size will be zero.

    return mkSubField(ZIP_EXTRA_ID_ZIP64, )
}

sub parseExtraField
{
    my $dataRef  = $_[0];
    my $strict   = $_[1];
    my $gzipMode = $_[2];
    #my $lax     = @_ == 2 ? $_[1] : 1;


    # ExtraField can be any of
    #
    #    -ExtraField => $data
    #
    #    -ExtraField => [$id1, $data1,
    #                    $id2, $data2]
    #                     ...
    #                   ]
    #
    #    -ExtraField => [ [$id1 => $data1],
    #                     [$id2 => $data2],
    #                     ...
    #                   ]
    #
    #    -ExtraField => { $id1 => $data1,
    #                     $id2 => $data2,
    #                     ...
    #                   }
    
    if ( ! ref $dataRef ) {

        return undef
            if ! $strict;

        return parseRawExtra($dataRef, undef, 1, $gzipMode);
    }

    my $data = $dataRef;
    my $out = '' ;

    if (ref $data eq 'ARRAY') {    
        if (ref $data->[0]) {

            foreach my $pair (@$data) {
                return ExtraFieldError("Not list of lists")
                    unless ref $pair eq 'ARRAY' ;

                my $bad = validateExtraFieldPair($pair, $strict, $gzipMode) ;
                return $bad if $bad ;

                $out .= mkSubField(@$pair);
            }   
        }   
        else {
            return ExtraFieldError("Not even number of elements")
                unless @$data % 2  == 0;

            for (my $ix = 0; $ix <= @$data -1 ; $ix += 2) {
                my $bad = validateExtraFieldPair([$data->[$ix],
                                                  $data->[$ix+1]], 
                                                 $strict, $gzipMode) ;
                return $bad if $bad ;

                $out .= mkSubField($data->[$ix], $data->[$ix+1]);
            }   
        }
    }   
    elsif (ref $data eq 'HASH') {    
        while (my ($id, $info) = each %$data) {
            my $bad = validateExtraFieldPair([$id, $info], $strict, $gzipMode);
            return $bad if $bad ;

            $out .= mkSubField($id, $info);
        }   
    }   
    else {
        return ExtraFieldError("Not a scalar, array ref or hash ref") ;
    }

    return ExtraFieldError("Too Large")
        if length $out > GZIP_FEXTRA_MAX_SIZE;

    $_[0] = $out ;

    return undef;
}

class ZipExtra
{
    has Blob $.local-extra-fields;
    has Blob $.central-extra-fields;

    method !mkSubField(Blob id, Blob $data)
    {
        return $id ~ pack("v", $data.elems) ~ $data ;
    }

    method add-extra-field-Zip64()
    {
    #   4.5.3 -Zip64 Extended Information Extra Field (0x0001):
    # 
    #      The following is the layout of the zip64 extended 
    #      information "extra" block. If one of the size or
    #      offset fields in the Local or Central directory
    #      record is too small to hold the required data,
    #      a Zip64 extended information record is created.
    #      The order of the fields in the zip64 extended 
    #      information record is fixed, but the fields MUST
    #      only appear if the corresponding Local or Central
    #      directory record field is set to 0xFFFF or 0xFFFFFFFF.
    # 
    #      Note: all fields stored in Intel low-byte/high-byte order.
    # 
    #        Value      Size       Description
    #        -----      ----       -----------
    #(ZIP64) 0x0001     2 bytes    Tag for this "extra" block type
    #        Size       2 bytes    Size of this "extra" block
    #        Original 
    #        Size       8 bytes    Original uncompressed file size
    #        Compressed
    #        Size       8 bytes    Size of compressed data
    #        Relative Header
    #        Offset     8 bytes    Offset of local header record
    #        Disk Start
    #        Number     4 bytes    Number of the disk on which
    #                              this file starts 
    # 
    #      This entry in the Local header MUST include BOTH original
    #      and compressed file size fields. If encrypting the 
    #      central directory and bit 13 of the general purpose bit
    #      flag is set indicating masking, the value stored in the
    #
    #      Local Header for the original file size will be zero.

        $.local-extra-fields ~= mkSubField(ZIP_EXTRA_ID_ZIP64, )
    }

    method mkExtendedTime
    {
        # order expected is m, a, c

        my $times = '';
        my $bit = 1 ;
        my $flags = 0;

        for my $time (@_)
        {
            if (defined $time)
            {
                $flags |= $bit;
                $times .= pack("V", $time);
            }

            $bit <<= 1 ;
        }

        return IO::Compress::Zlib::Extra::mkSubField(ZIP_EXTRA_ID_EXT_TIMESTAMP,
                                                     pack("C", $flags) .  $times);
    }



}
