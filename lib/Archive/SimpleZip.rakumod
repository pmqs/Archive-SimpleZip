
unit module Archive::SimpleZip:ver<0.6.0>:auth<zef:pmqs>;

need Compress::Zlib;
need Compress::Bzip2;

use IO::Glob;

use Archive::SimpleZip::Utils ;
use Archive::SimpleZip::Headers ;#:ALL :DEFAULT<Zip-CM>;

# Use CompUnit::Util for now to re-export the Zip-CM enum
# from Archive::SimpleZip::Headers.
# rakudo issue seems to be this ticket: https://github.com/perl6/roast/issues/45
use CompUnit::Util :re-export;
BEGIN re-export('Archive::SimpleZip::Headers');


class SimpleZip does Callable is export
{
    has IO::Handle               $!zip-filehandle ;
    has IO::Path                 $.filename ;
    has Str                      $.comment ;
    has Instant                  $!now = DateTime.now.Instant;
    has Zip-CM                   $!default-method ;
    has Bool                     $!any-zip64 = False;

    # Defaults
    has Bool                     $!zip64 = False ;
    has Bool                     $.default-stream ;
    has Bool                     $.default-canonical ;

    has Central-Header-Directory $!cd .= new() ;

    has Bool                     $!opened = True;

    multi method new(IO:D() $filename, |c)
    {
        my $zip-filehandle = open $filename, :w, :bin ;
        self.bless(:$zip-filehandle, filename => $filename.IO, |c);
    }

    multi submethod BUILD(IO::Handle:D :$!zip-filehandle?,
                          IO::Path:D   :$!filename?,
                          Str:D        :$!comment = "",
                          Bool:D       :stream($!default-stream) = False,
                          Bool:D       :canonical-name($!default-canonical) = True,
                          Zip-CM:D     :method($!default-method) = Zip-CM-Deflate,
                         #Bool:D       :$!zip64   = False,
                         )
    {
        $!any-zip64 = True
            if $!zip64 ;
    }

    multi method CALL-ME(IO() $path, |c --> IO)
    {
        return $path
            unless $path ;

        self.add($path, |c);

        $path;
    }

    multi method CALL-ME(IO::Glob:D $glob, |c --> IO::Glob:D)
    {
        $glob.map: { self.add($^a, |c) } ;

        $glob
    }

    multi method AT-KEY (::?CLASS:D: $key) is rw {

        my $self = self;

        Proxy.new(
            FETCH => method () { $key },

            STORE => method ($value) {
                $self.create($key, $value);
            }
        );
    }

    # method EXISTS-KEY ($key)       {  }
    # method DELETE-KEY ($key)       { }

    # multi method add(Str:D $string, |c --> Int:D)
    # {
    #     # say "ADDING String [{$string.^name}][$string]";

    #     my IO::Blob $fh .= new($string);
    #     samewith($fh, |c);
    # }

    # multi method add(Blob:D $blob, |c --> Int:D)
    # {
    #     my IO::Blob $fh .= new($blob);
    #     samewith($fh, |c);
    # }



    multi method add(IO:D() $path, |c --> Int:D)
    {
        # Fail immediately if file doesn't exist or isn't readable
        my $fh = open($path, :r, :bin)
            or fail $fh ;

        samewith($fh, :name(Str($path)), :time($path.modified), |c);
    }

    multi method add(IO::Glob:D $glob, |c --> Int:D)
    {
        samewith($glob.dir, |c);
    }

    multi method add(Seq:D $s, |c --> Int:D)
    {
        # say "ADDING Seq [{$s.^name}][$s]";

        my $count = 0;
        $s.map: { samewith($^a, |c) ; ++ $count} ;

        return $count;
    }

    multi method add(List:D $l, |c --> Int:D)
    {
        # say "ADDING List [{$l.^name}][$l]";

         $l.map: { samewith($^a, |c) } ;

        return $l.elems;
    }

    multi method add(IO::Handle:D  $handle, |c --> Int:D)
    {
        my $p  = -> $compress-chunk {
                        while $handle.read(1024 * 4) -> $chunk
                        {
                            $compress-chunk($chunk);
                        }
                    } ;
        self!create-zip-entry($p, |c);
    }

    multi method create(Str:D() $name, IO::Handle:D  $handle, |c --> Int:D)
    {
        my $p  = -> $compress-chunk {
                        while $handle.read(1024 * 4) -> $chunk
                        {
                            $compress-chunk($chunk);
                        }
                    } ;

        self!create-zip-entry($p, :name($name), |c);
    }

    multi method create(Str:D() $name, IO:D() $path, |c --> Int:D)
    {
        # Fail immediately if file doesn't exist or isn't readable
        my $fh = open($path, :r, :bin)
            or fail $fh ;

        samewith($name, $fh, :time($path.modified), |c);
    }

    multi method create(Str:D() $name, Str:D() $str, |c --> Int:D)
    {
        my $p  = -> $compress-chunk {
                       $compress-chunk($str.encode);
                    } ;
        self!create-zip-entry($p, :name($name), |c);
    }

    multi method create(Str:D() $name, Blob:D() $blob, |c --> Int:D)
    {
        my $p  = -> $compress-chunk {
                        $compress-chunk($blob);
                    } ;
        self!create-zip-entry($p, :name($name), |c);
    }

    method !create-zip-entry(Code:D        $process-input,
                             Str:D        :$name    = '',
                             Str:D        :$comment = '',
                             Instant:D    :$time    = $!now,
                             Bool:D       :$stream  = $!default-stream,
                             Bool:D       :$canonical-name = $!default-canonical,
                             Zip-CM:D     :$method  = $!default-method
                             --> Int:D)
    {
        my $compressed-size = 0;
        my $uncompressed-size = 0;
        my $crc32 = 0;
        my $hdr = Local-File-Header.new();

        $hdr.last-mod-file-time = get-DOS-time($time);
        $hdr.compression-method = $method ;

        my Str $filename = $name ;
        $filename = make-canonical-name($filename)
            if $canonical-name ;

        # Check if the filename or comment are 7-bit ASCII
        # If either is not, set the Language encoding bit
        # in general purpose flags.
        my Bool $high-bit = ( ? $filename.ords.first: * > 127 ) ||
                            ( ? $comment.ords.first:  * > 127 );

        $hdr.file-name = $filename.encode ;

        $hdr.file-comment = $comment.encode;

        $hdr.general-purpose-bit-flag +|= Zip-GP-Streaming-Mask
            if $stream ;

        $hdr.general-purpose-bit-flag +|= Zip-GP-Language-Encoding
            if $high-bit ;

        my $start-local-hdr = $!zip-filehandle.tell();
        my $local-hdr = $hdr.get();
        $!zip-filehandle.write($local-hdr) ;

        my $compress-action;
        my $flush-action;

        given $method
        {
            when Zip-CM-Deflate
            {
                my $zlib = Compress::Zlib::Stream.new(:deflate);
                $compress-action  = -> $in { $zlib.deflate($in) } ;
                $flush-action     = ->     { $zlib.finish()     } ;
            }

            when Zip-CM-Bzip2
            {
                my $bzip2 = Compress::Bzip2::Stream.new(:deflate);
                $compress-action  = -> $in { $bzip2.compress($in) } ;
                $flush-action     = ->     { $bzip2.finish()      } ;
            }

            when Zip-CM-Store
            {
                $compress-action  = -> $in { $in         } ;
                $flush-action     = ->     { Blob.new()  } ;
            }
        }

        # These are done for all compression formats
        my $compress-chunk  = -> $chunk { $uncompressed-size += $chunk.elems;
                                          $crc32 = crc32($crc32, $chunk);
                                          my $out = $compress-action($chunk);
                                          $compressed-size += $out.elems;
                                          $!zip-filehandle.write($out)
                                        } ;

        my $flusher = ->  { my $out = $flush-action();
                            $compressed-size += $out.elems;
                            $!zip-filehandle.write($out)
                          } ;

        $process-input($compress-chunk);
        $flusher();

        $hdr.compressed-size = $compressed-size ;
        $hdr.uncompressed-size = $uncompressed-size;
        $hdr.crc32 = $crc32;

        if $stream
        {
            $!zip-filehandle.write($hdr.data-descriptor()) ;
        }
        else
        {
            my $here = $!zip-filehandle.tell();
            $!zip-filehandle.seek($start-local-hdr + 14, SeekFromBeginning);
            $!zip-filehandle.write($hdr.crc-and-sizes());
            $!zip-filehandle.seek($here, SeekFromBeginning);
        }

        $!cd.save-hdr($hdr, $start-local-hdr);

        return 1;
    }

    method close()
    {
        return True
            if ! $!opened;

        $!opened = False;

        my $start-cd = $!zip-filehandle.tell();

        for $!cd.get-hdrs() -> $ch
        {
            $!zip-filehandle.write($ch) ;
        }

        $!zip-filehandle.write($!cd.end-central-directory($start-cd, $.comment.encode));

        $!zip-filehandle.close();

        return True;
    }

    method DESTROY()
    {
        self.close();
    }

}

=begin pod
=NAME       Archive::SimpleZip
=SYNOPSIS

    use Archive::SimpleZip;

    # Create a zip archive in filesystem
    my $obj = SimpleZip.new("mine.zip");

    # Add a file to the zip archive
    $obj.add("somefile.txt".IO);

    # Add a Blob/String to the zip archive
    $obj.add("payload data here", :name<data1>);
    $obj.add(Blob.new([2,4,6]), :name<data2>);

    # Drop a filehandle into the zip archive
    my $handle = "some file".IO.open;
    $obj.add($handle, :name<data3>);

    # Add a glob of files
    use IO::Glob;
    $zip.add(glob("*.c"));

    # Add a list of files
    $zip.add();


    $obj.close();

=DESCRIPTION

Simple write-only interface to allow creation of Zip files.

Please note - this is module is a prototype. The interface will change.

=head1 METHODS

=head2 method new

Instantiate a SimpleZip object

    my $zip = SimpleZip.new("my.zip");

If the first parameter is a string or IO::Path the zip archive will be
created in the filesystem.

=head3 Options

Most of these options control the setting of defaults that will be used in
subsequent calls to the C<add> method.

The default setting can be overridden for an individual member where the
constructor, C<new>, and the C<add> method have an identically named
options.

For example:

    #  Set the default to make all members in the archive streamed.
    my $zip = SimpleZip.new($archive, :stream);

    # This uses the default, so is streamed
    $zip.add("file1".IO)  ;

    # This changes the default, so is NOT streamed
    $zip.add("file1".IO, :!stream)  ;

    # This uses the default, so is streamed
    $zip.add("file1".IO)  ;

=head4 stream => True|False

Write the zip archive in streaming mode. Default is False.

    my $zip = SimpleZip.new($archive, :stream);

Specify the C<stream> option on individual call to C<add> to override
this default.

=head4 method => Zip-CM-Deflate|Zip-CM-Store

Used to set the default compression algorithm used for all members of the
archive. If not specified then <Zip-CM-Deflate> is the default.

Specify the C<method> option on individual call to C<add> to override
this default.

Valid values are

=item Zip-CM-Deflate
=item Zip-CM-Store

=head4 comment => String

Creates a comment for the archive.

    my $zip = SimpleZip.new($archive, comment => "my comment");

=head4 canonical-name => True|False

Used to set the default for I<normalizing> the I<name> field before it is
written to the zip archive. The normalization carried out involves
converting the name into a Unix-style relative path.

To be precise, this is what APPNOTE.TXT (the specification for Zip
archives) has to say on what should be stored in the zip name header field.

    The name of the file, with optional relative path.
    The path stored MUST not contain a drive or
    device letter, or a leading slash.  All slashes
    MUST be forward slashes '/' as opposed to
    backwards slashes '\' for compatibility with Amiga
    and UNIX file systems etc.

Unless you have a use-case that needs non-standard Zip member names, you
should leave this option well alone.

Unsurprizingly then, the default for this option is True.

Example

    my $zip = SimpleZip.new($archive, :!canonical-name);

=head4 Bool zip64 => True|False

TODO

Specify the C<zip64> option on individual call to C<add> to override
this default.

=head2 method add

Used to add one or more a files, a string or a blob to a Zip archive. The method expects one
mandatory parameter and zero or more optional parameters.
Returns the number of files added.

To add a file from the filesystem the first parameter must be of type
IO::Path

    # Add a file to the zip archive
    $zip.add("/tmp/fred".IO);

To add a string/blob to the archive

    # Add a string to the zip archive
    $zip.add("payload data here", :name<data1>);

    # Add a blob to the zip archive
    my Blob $data .= new;
    $zip.add($data, :name<data1>);

To add a list of files

    use IO::Glob;
    $zip.add(glob("*.c"));

=head3 Options

=head4 name => String

Set the B<name> field in the zip archive.

When a filename is passed to C<add>, the value passed in this option will
be stored in the Zip archive, rather than the filename.

If the canonical-name option is True, the name will be normalized to Unix
format before being written to the Zip archive.

=head4 method => Zip-CM-Deflate|Zip-CM-Store

Used to set the compression algorithm used for this member. If C<method>
has not been specifed here or in C<new> it will default to
C<Zip-CM-Deflate>.

Valid values are

=item Zip-CM-Deflate
=item Zip-CM-Store

=head4 Bool stream => True|False

Write this member in streaming mode.

=head4 comment

Creates a comment for the member.

    my $zip = SimpleZip.new($archive, comment => "my comment");

=head4 canonical-name  => True|False

Controls how the I<name> field is written top the zip archive. See the

=head4 zip64 => True|False

=head1 TODO

=item Zip64
=item Support for extra fields
=item Standard extra fields for better time
=item Adding directories

=AUTHOR Paul Marquess <pmqs@cpan.org>
=end pod
