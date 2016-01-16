
unit module Archive::SimpleZip;

use v6;
use experimental :pack;

need Compress::Zlib::Raw;
need Compress::Zlib;

use NativeCall;
use IO::Blob;

sub crc32(int32 $crc, Blob $data)
{
    my $indata := nativecast CArray[uint8], $data ;
    my int32 $newCrc = Compress::Zlib::Raw::crc32($crc, $indata, $data.bytes);

    return $newCrc;
}

# Compression types supported
enum Zip-CM is export (
    Zip-CM-Store      => 0 ,
    Zip-CM-Deflate    => 8 ,
    #Zip-CM-BZIP2      => 12 , # Not supported yet
    #Zip-CM-LZMA       => 14 , # Not Supported yet
    #Zip-CM-PPMD       => 98 , # Not Supported yet
);

# General Purpose Flag
enum Zip-GP-Flag (
    Zip-GP-Encrypted_Mask        => (1 +< 0) ,
    Zip-GP-Streaming-Mask        => (1 +< 3) ,
    Zip-GP-Patched-Mask          => (1 +< 5) ,
    Zip-GP-Strong-Encrypted-Mask => (1 +< 6) ,
    Zip-GP-LZMA-EOS-Present      => (1 +< 1) ,
    Zip-GP-Language-Encoding     => (1 +< 11) ,
);

our %Zip-CM-Min-Versions = 
            Zip-CM-Store                     => 20,
            Zip-CM-Deflate                   => 20,
            #Zip-CM-BZIP2                     => 46,
            #Zip-CM-LZMA                      => 63,
            #Zip-CM-PPMD                      => 63,
            ;

class Local-File-Header 
{

    #   4.3.7  Local file header:
    #
    #      local file header signature     4 bytes  (0x04034b50)
    #      version needed to extract       2 bytes
    #      general purpose bit flag        2 bytes
    #      compression method              2 bytes
    #      last mod file time              2 bytes
    #      last mod file date              2 bytes
    #      crc-32                          4 bytes
    #      compressed size                 4 bytes
    #      uncompressed size               4 bytes
    #      file name length                2 bytes
    #      extra field length              2 bytes
    #
    #      file name (variable size)
    #      extra field (variable size)

    constant local-file-header-signature = 0x04034b50 ; # 4 bytes  (0x04034b50)

    has Int   $.version-needed-to-extract is rw = 0;   # 2 bytes
    has Int   $.general-purpose-bit-flag is rw = 0;    # 2 bytes
    has Int   $.compression-method is rw = 0;          # 2 bytes
    has Int   $.last-mod-file-time is rw = 0;          # 2 bytes
    has Int   $.last-mod-file-date is rw = 0;          # 2 bytes
    has Int   $.crc32 is rw = 0;                       # 4 bytes
    has Int   $.compressed-size is rw = 0;             # 4 bytes
    has Int   $.uncompressed-size is rw = 0;           # 4 bytes
    has Int   $.file-name-length is rw = 0;            # 2 bytes
    has Int   $.extra-field-length is rw = 0;          # 2 bytes
    has Blob  $.file-name is rw ;                      # variable size


    has Int   $.version-made-by is rw = 0;             # 2 bytes
    has Blob  $.file-comment is rw  ;                  # 2 bytes
    has Int   $.internal-file-attributes is rw = 0;    # 2 bytes
    has Int   $.external-file-attributes is rw = 0;    # 4 bytes

    method setMethod(Zip-CM $cm)
    {
        $.compression-method = $cm ;
    }


    method get()
    {
        $.version-needed-to-extract max=
            %Zip-CM-Min-Versions{$.compression-method} ;

        my Blob $hdr ;
        $hdr  = pack 'V', local-file-header-signature ;

        $hdr ~= pack 'v', $.version-needed-to-extract   ; # 2 bytes
        $hdr ~= pack 'v', $.general-purpose-bit-flag ;    # 2 bytes
        $hdr ~= pack 'v', $.compression-method ;          # 2 bytes
        $hdr ~= pack 'v', $.last-mod-file-time ;          # 2 bytes
        $hdr ~= pack 'v', $.last-mod-file-date ;          # 2 bytes
        $hdr ~= pack 'V', $.crc32 ;                       # 4 bytes
        $hdr ~= pack 'V', $.compressed-size ;             # 4 bytes
        $hdr ~= pack 'V', $.uncompressed-size ;           # 4 bytes
        $hdr ~= pack 'v', $.file-name.elems;              # 2 bytes
        $hdr ~= pack 'v', $.extra-field-length ;          # 2 bytes
        $hdr ~= $.file-name ;

        return $hdr ;
    }

    method data-descriptor()
    {
        #   4.3.9  Data descriptor:
        #
        #        crc-32                          4 bytes
        #        compressed size                 4 bytes
        #        uncompressed size               4 bytes    

        constant signature = 0x08074b50 ; # 4 bytes  (0x04034b50)
        my Blob $hdr ;
        $hdr  = pack 'V', signature ;
        $hdr ~= pack 'V', $.crc32 ;                       # 4 bytes
        $hdr ~= pack 'V', $.compressed-size ;             # 4 bytes
        $hdr ~= pack 'V', $.uncompressed-size ;           # 4 bytes

        return $hdr ;
    }

    method crc-and-sizes()
    {
        my Blob $hdr ;
        $hdr  = pack 'V', $.crc32 ;                       # 4 bytes
        $hdr ~= pack 'V', $.compressed-size ;             # 4 bytes
        $hdr ~= pack 'V', $.uncompressed-size ;           # 4 bytes

        return $hdr ;
    }
} 


class Central-Header-Directory
{
    has       @!central-headers ;
    has       $!entries;
    has       $!cd-len ;

    method get-hdrs()
    {
        return @!central-headers ;
    }

    method end-central-directory(Int $cd_offset, Blob $comment)
    {
        #   4.3.16  End of central directory record:
        #
        #      end of central dir signature    4 bytes  (0x06054b50)
        #      number of this disk             2 bytes
        #      number of the disk with the
        #      start of the central directory  2 bytes
        #      total number of entries in the
        #      central directory on this disk  2 bytes
        #      total number of entries in
        #      the central directory           2 bytes
        #      size of the central directory   4 bytes
        #      offset of start of central
        #      directory with respect to
        #      the starting disk number        4 bytes
        #      .ZIP file comment length        2 bytes
        #      .ZIP file comment       (variable size)
                
        my Blob $ecd ;
        $ecd  = pack "V", 0x06054b50 ; #ZIP_END_CENTRAL_HDR_SIG ; # signature
        $ecd ~= pack 'v', 0          ; # number of disk
        $ecd ~= pack 'v', 0          ; # number of disk with central dir
        $ecd ~= pack 'v', $!entries   ; # entries in central dir on this disk
        $ecd ~= pack 'v', $!entries   ; # entries in central dir
        $ecd ~= pack 'V', $!cd-len    ; # size of central dir
        $ecd ~= pack 'V', $cd_offset ; # offset to start central dir
        $ecd ~= pack 'v', $comment.elems ; # zipfile comment length
        #$ecd ~= pack 'v', 0; # zipfile comment length
        $ecd ~= $comment;

        return $ecd;
    }

    method save-hdr(Local-File-Header $hdr, Int $offset)
    {
        #   4.3.12  Central directory structure:
        #
        #      [central directory header 1]
        #      .
        #      .
        #      . 
        #      [central directory header n]
        #      [digital signature] 
        #
        #      File header:
        #
        #        central file header signature   4 bytes  (0x02014b50)
        #        version made by                 2 bytes
        #        version needed to extract       2 bytes
        #        general purpose bit flag        2 bytes
        #        compression method              2 bytes
        #        last mod file time              2 bytes
        #        last mod file date              2 bytes
        #        crc-32                          4 bytes
        #        compressed size                 4 bytes
        #        uncompressed size               4 bytes
        #        file name length                2 bytes
        #        extra field length              2 bytes
        #        file comment length             2 bytes
        #        disk number start               2 bytes
        #        internal file attributes        2 bytes
        #        external file attributes        4 bytes
        #        relative offset of local header 4 bytes
        #
        #        file name (variable size)
        #        extra field (variable size)
        #        file comment (variable size)
        
        my Blob $ctl ;

        $ctl  = pack "V", 0x02014b50 ; # ZIP_CENTRAL_HDR_SIG ; # signature
        $ctl ~= pack 'v', $hdr.version-made-by    ; # version made by
        $ctl ~= pack 'v', $hdr.version-needed-to-extract   ; # extract Version & OS
        $ctl ~= pack 'v', $hdr.general-purpose-bit-flag ;    # 2 bytes
        $ctl ~= pack 'v', $hdr.compression-method ;          # 2 bytes
        $ctl ~= pack 'v', $hdr.last-mod-file-time ;          # 2 bytes
        $ctl ~= pack 'v', $hdr.last-mod-file-date ;          # 2 bytes
        $ctl ~= pack 'V', $hdr.crc32 ;                       # 4 bytes
        $ctl ~= pack 'V', $hdr.compressed-size ;             # 4 bytes
        $ctl ~= pack 'V', $hdr.uncompressed-size ;           # 4 bytes
        $ctl ~= pack 'v', $hdr.file-name.elems ;             # 2 bytes
        $ctl ~= pack 'v', $hdr.extra-field-length ;          # 2 bytes
        $ctl ~= pack 'v', $hdr.file-comment.elems ;          # 2 bytes
        $ctl ~= pack 'v', 0                     ;            # 2 bytes
        $ctl ~= pack 'v', $hdr.internal-file-attributes ;    # 2 bytes
        $ctl ~= pack 'V', $hdr.external-file-attributes ;    # 4 bytes
        $ctl ~= pack 'V', $offset ;                          # 4 bytes
        $ctl ~= $hdr.file-name ;
        $ctl ~= $hdr.file-comment ;

        @!central-headers.push($ctl) ;
        $!cd-len += $ctl.elems ; 
        ++ $!entries;
    }

}

class ProxyWrite
{
    #123838: IO::Handle::tell return 0, no matter what

    has IO::Handle               $!filehandle ;
    has Int                      $!offset = 0 ;

    multi submethod BUILD(IO::Handle :$!filehandle) 
    {
    }

    method write(Blob $data)
    {
        $!offset += $data.elems;
        $!filehandle.write($data);
    }

    method write-at(Int $index, Blob $data)
    {
        $!filehandle.seek($index, SeekFromBeginning);
        $!filehandle.write($data);
        $!filehandle.seek($!offset, SeekFromBeginning);
    }

    method tell()
    {
        return $!offset;
    }
    method close()
    {
        close $!filehandle;
    }
}

class SimpleZip is export
{
    has IO::Handle               $!zip-filehandle ;
    has IO::Path                 $.filename ;
    has Str                      $.comment ;
    has Bool                     $.stream ;
 
    has Bool                     $!any-zip64 = False;
    has Bool                     $!zip64 = False ;
    has Central-Header-Directory $!cd .= new() ;

    has Bool                     $!opened = True;

    #123838: IO::Handle::tell return 0, no matter what
    has ProxyWrite               $!out ;

    multi method new(Str $filename, |c)
    {
        my $zip-filehandle = open $filename, :w, :bin ;
        self.bless(:$zip-filehandle, filename => $filename.IO, |c);
    }

    multi method new(IO::Path $filename, |c)
    {
        my $zip-filehandle = open $filename, :w, :bin ;
        self.bless(:$zip-filehandle, :$filename, |c);
    }

    multi method new(Blob $data, |c)
    {
        my IO::Blob $zip-filehandle .= new($data);
        self.bless(:$zip-filehandle, |c);
    }

    multi submethod BUILD(IO::Handle :$!zip-filehandle?, 
                          IO::Path   :$!filename?,
                          Bool       :$!stream  = False, 
                          Str        :$!comment = ""
                         #Bool       :$!zip64   = False, 
                         )
    {
        $!out .= new(filehandle => $!zip-filehandle); 
        $!any-zip64 = True 
            if $!zip64 ;
    }

    multi method add(Str $string, |c)
    {
        #say "add Str";
        my IO::Blob $fh .= new($string);
        samewith($fh, |c);
    }

    multi method add(IO::Path $path, |c)
    {
        #say "add IO";
        my IO::Handle $fh = open($path, :r, :bin);
        samewith($fh, |c);
    }

    multi method add(IO::Handle  $handle, 
                     Str        :$name?, 
                     Str        :$comment = '',
                     Zip-CM     :$method  = Zip-CM-Deflate)
    {
        my $compressed-size = 0;
        my $uncompressed-size = 0;
        my $crc32 = 0;

        my $hdr = Local-File-Header.new();

        $hdr.compression-method = $method ;
        $hdr.file-name = ($name // "name").encode ;
        $hdr.file-comment = $comment.encode;

        $hdr.general-purpose-bit-flag +|= Zip-GP-Streaming-Mask 
            if $.stream ;

        my $start-local-hdr = $!out.tell();
        my $local-hdr = $hdr.get();
        $!out.write($local-hdr) ;

        my $read-action;
        my $flush-action;

        given $method
        {
            when Zip-CM-Deflate 
            {
                my $zlib = Compress::Zlib::Stream.new(:deflate);
                $read-action  = -> $in { $zlib.deflate($in) } ;
                $flush-action = ->     { $zlib.finish()     } ;
            }

            when Zip-CM-Store
            {
                $read-action  = -> $in { $in         } ;
                $flush-action = ->     { Blob.new()  } ;
            }
        }

        # These are done for all compression formats
        my $reader  = -> $in { $uncompressed-size += $in.elems;  
                               $crc32 = crc32($crc32, $in);
                               my $out = $read-action($in); 
                               $compressed-size += $out.elems; 
                               $out
                             } ; 
        my $flusher = ->     { my $out = $flush-action(); 
                               $compressed-size += $out.elems; 
                               $out
                             } ;

        while $handle.read(1024 * 4) -> $chunk
        {
            $!out.write($reader($chunk));
        }
        $!out.write($flusher());

        $hdr.compressed-size = $compressed-size ;
        $hdr.uncompressed-size = $uncompressed-size;
        $hdr.crc32 = $crc32;

        if $.stream
        {
            $!out.write($hdr.data-descriptor()) ;
        }
        else
        {
            $!out.write-at($start-local-hdr + 14, $hdr.crc-and-sizes()) ;
        }

        $!cd.save-hdr($hdr, $start-local-hdr);
    }

    method close()
    {
        return True
            if ! $!opened;

        $!opened = False;

        my $start-cd = $!out.tell();
        
        for $!cd.get-hdrs() -> $ch
        {
            $!out.write($ch) ;
        }

        $!out.write($!cd.end-central-directory($start-cd, $.comment.encode));

        $!zip-filehandle.close();

        return True;
    }

    method DESTROY()
    {
        self.close();
    }

};
