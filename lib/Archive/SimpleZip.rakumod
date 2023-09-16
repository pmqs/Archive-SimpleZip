
unit module Archive::SimpleZip:ver<0.7.0>:auth<zef:pmqs>;

need Compress::Zlib;
need Compress::Bzip2;

use IO::Glob;

use Archive::SimpleZip::Utils ;
use Archive::SimpleZip::Headers ;

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

    # multi method new(IO::Handle:D() $filehandle, Str:D() $filename,, |c)
    # {
    #     my $zip-filehandle = $filehandle ;
    #     self.bless(:$zip-filehandle, filename => $filename.IO, |c);
    # }

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

    # CALL-ME
    multi method CALL-ME(IO() $path, |c --> IO)
    {
        # say "CM [$path] " ~ $path.^name;
        return $path
            unless $path ;

        self.add($path, |c);

        $path;
    }

    multi method CALL-ME(Iterable:D $i, |c --> Seq:D)
    {
        # say "In CALL-ME Iterable ";
        gather {
            $i.map: { self.add($^a, |c) ; take $^a } ;
        }
    }

    # multi method AT-KEY (::?CLASS:D: $key) is rw
    # {

    #     my $self = self;

    #     Proxy.new(
    #         FETCH => method () { $key },

    #         STORE => method ($value) {
    #             $self.create($key, $value);
    #         }
    #     );
    # }

    multi method ASSIGN-KEY (::?CLASS:D: $key, $value)
    {
        self.create($key, $value);
    }

    # method EXISTS-KEY ($key)       {  }
    # method DELETE-KEY ($key)       { }

    # add method deals with file(s) from the filesystem

    multi method add(IO:D() $path, |c --> Int:D)
    {
        if $path.d
        {
            self.mkdir($path, |c)
        }
        else
        {
            # Fail immediately if file doesn't exist or isn't readable
            my $fh = open($path, :r, :bin)
                or fail $fh ;

            my $p  = -> $compress-chunk {
                            while $fh.read(1024 * 4) -> $chunk
                            {
                                $compress-chunk($chunk);
                            }
                        } ;

            self!create-zip-entry($p, :original-path($path),
                                  :time($path.modified), :empty(! $path.s.Bool), |c);
        }
    }

    multi method add(Iterable:D $s, |c --> Int:D)
    {
        my $count = 0;
        $s.map: { samewith($^a, |c) ; ++ $count} ;

        return $count;
    }

    multi method mkdir(Str:D() $name, |c --> Int:D)
    {
        my $p  = -> $compress-chunk {
                       "";
                    } ;

        self!create-zip-entry($p, :original-path($name), :empty, :is-directory, |c);
    }

    multi method mkdir(Iterable:D $d, |c --> Int:D)
    {
        my $count = 0;
        $d.map: { samewith($^a, |c) ; ++ $count } ;

        return $count;
    }

    multi method create(Str:D() $name, IO::Handle:D  $handle, |c --> Int:D)
    {
        my $p  = -> $compress-chunk {
                        while $handle.read(1024 * 4) -> $chunk
                        {
                            $compress-chunk($chunk);
                        }
                    } ;

        self!create-zip-entry($p, :original-path($name), |c);
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
        self!create-zip-entry($p, :original-path($name), :empty(! $str.elems.Bool), |c);
    }

    multi method create(Str:D() $name, Blob:D() $blob, |c --> Int:D)
    {
        my $p  = -> $compress-chunk {
                        $compress-chunk($blob);
                    } ;
        self!create-zip-entry($p, :original-path($name), :empty(! $blob.elems.Bool), |c);
    }



    method !create-zip-entry(Code:D        $process-input,
                                          :$name  where Str:D()|Code:D(),
                             Str()        :$original-path  = '',
                             Str:D        :$comment        = '',
                             Instant:D    :$time           = $!now,
                             Bool:D       :$stream         = $!default-stream,
                             Bool:D       :$canonical-name = $!default-canonical,
                             Zip-CM:D     :$method         = $!default-method,
                             Bool:D       :$empty          = False,
                             Bool:D       :$is-directory   = False
                             --> Int:D)
    {
        my $compressed-size = 0;
        my $uncompressed-size = 0;
        my $crc32 = 0;
        my $hdr = Local-File-Header.new();

        $hdr.last-mod-file-time = get-DOS-time($time);
        $hdr.compression-method =  $empty ?? Zip-CM-Store !! $method ;

        my Str $filename =
                    do given $name {
                        when Code:D { $name($original-path) }
                        when Str:D  { $name.Str             }
                        default     { $original-path        }
                    } ;

        $filename = make-canonical-name($filename, $is-directory)
            if $canonical-name ;

        # Check that the filename or comment are 7-bit ASCII.
        # If either is not, set the Language encoding bit
        # in general purpose flags.
        my Bool $high-bit-set = ( ? $filename.ords.first: * > 127 ) ||
                                ( ? $comment.ords.first:  * > 127 );

        $hdr.file-name    = $filename.encode ;
        $hdr.file-comment = $comment.encode;

        $hdr.general-purpose-bit-flag +|= Zip-GP-Streaming-Mask
            if $stream && !$empty ;

        $hdr.general-purpose-bit-flag +|= Zip-GP-Language-Encoding
            if $high-bit-set ;

        my $start-local-hdr-offset = $!zip-filehandle.tell();
        my $local-hdr = $hdr.get();
        $!zip-filehandle.write($local-hdr) ;

        if ! $empty
        {
            # Only jump through copmpression hoops when there
            # is a payload to compress.

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
        }

        $hdr.compressed-size = $compressed-size ;
        $hdr.uncompressed-size = $uncompressed-size;
        $hdr.crc32 = $crc32;

        if ! $empty
        {
            if $stream
            {
                $!zip-filehandle.write($hdr.data-descriptor()) ;
            }
            else
            {
                my $here = $!zip-filehandle.tell();
                $!zip-filehandle.seek($start-local-hdr-offset + 14, SeekFromBeginning);
                $!zip-filehandle.write($hdr.crc-and-sizes());
                $!zip-filehandle.seek($here, SeekFromBeginning);
            }
        }

        $!cd.save-hdr($hdr, $start-local-hdr-offset);

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

    # Create a zip file in the filesystem
    my $z = SimpleZip.new: "mine.zip";

    # Add a file to the zip archive
    $z.add: "/some/file.txt";

    # Add multiple files in one step
    # the 'add' method will consume anything that is an Iterable
    $z.add: @list_of_files;

    # change the compression method to STORE
    $z.add: 'somefile', :method(Zip-CM-Store);

    # change the compression method to use Bzip2 compression
    $z.add: 'somefile', :method(Zip-CM-Bzip2);

    # add knows what to do with IO::Glob
    use IO::Glob;
    $z.add: glob("*.c");

    # add a file, but call it something different in the zip file
    $z.add: "/some/file.txt", :name<better-name>;

    # algorithmically rename the files by passing code to the name option
    # in this instance chage file extension from '.tar.gz' to ;.tgz'
    $z.add: @list_of_files, :name( *.subst(/'.tar.gz' $/, '.tgz') ), :method(Zip-CM-Store);

    # when used in a method chain it will accept an Iterable and output a Seq of filenames

    # add all files matched by IO::Glob
    glob("*.c").dir.$z ;

    # or like this
    glob("*.c").$z ;

    # contrived example
    glob("*.c").grep( ! *.d).$z.uc.sort.say;

    # Create a zip entry from a string/blob

    $z.create(:name<data1>, "payload data here");
    $z.create(:name<data2>, Blob.new([2,4,6]));

    # Drop a filehandle into the zip archive
    my $handle = "/another/file".IO.open;
    $z.create("data3", $handle);

    # use Associative interface to call 'create' behind the secenes
    $z<data4> = "more payload";

    # can also use Associative interface to add a file from the filesystem
    # just make sure it is of type IO
    $z<data5> = "/real/file.txt".IO;

    # or a filehandle
    $z<data5> = $handle;

    # create a directory
    $z.mkdir: "dir1";

    $z.close;

=DESCRIPTION

Simple write-only interface to allow creation of Zip files in the filesystem.

Please note - this is module is a prototype. The interface will change.

=head1 METHODS

=head2 method new($filename [, options] )

Instantiate a C<SimpleZip> object

    my $zip = SimpleZip.new: "my.zip";

Takes one mandatoty parameter, namely the name of the zip file to create in the
filesystem, and zero or more optional parameters.

=head3 Options

Most of these options control the setting of defaults that will be used in
subsequent calls to the C<add> or C<create> methods.

The default setting can be overridden for an individual member where the
constructor, C<new>, and the C<add>/C<create> methods have an identically named
options.

For example:

    #  Set the default to make all members in the archive streamed.
    my $zip = SimpleZip.new($archive, :stream);

    # This uses the default, so is streamed
    $zip.add: "file1" ;

    # This changes the default, so is NOT streamed
    $zip.add("file2".IO, :!stream)  ;

    # This uses the default, so is streamed
    $zip.add("file3".IO)  ;

=head4 stream => True|False

Write the zip archive in I<streaming mode>. Default is C<False>.

    my $zip = SimpleZip.new($archive, :stream);

Specify the C<stream> option on individual calls to C<add>/C<create> to override
this default.

=head4 method => Zip-CM-Deflate|Zip-CM-Store|Zip-CM-Bzip2

Used to set the default compression algorithm used for all members of the
archive. If not specified then <Zip-CM-Deflate> is the default.

The exception is when the code is certain there is no payload data to be stored
in the zip archive, in which case C<Zip-CM-Store> will be used.
Examples are for empty files, or directories.

Specify the C<method> option on individual calls to C<add>/C<create> to override
this default.

Valid values are

=item C<Zip-CM-Deflate>
=item C<Zip-CM-Store>
=item C<Zip-CM-Bzip2>

=head4 comment => String

Creates a comment for the archive.

    my $zip = SimpleZip.new($archive, :comment<filefile comment>);

=head4 canonical-name => True|False

Used to set the default for I<normalizing> the I<name> field before it is
written to the zip archive. The normalization carried out involves
converting the name into a Unix-style relative path.

For example, the following shows how to disable the normalization of filenames:

    my $zip = SimpleZip.new($archive, :!canonical-name);

Below is what L<APPNOTE.TXT|https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT>
(the specification for Zip archives)
has to say on what should be stored in the zip name header field.

    The name of the file, with optional relative path.
    The path stored MUST not contain a drive or
    device letter, or a leading slash.  All slashes
    MUST be forward slashes '/' as opposed to
    backwards slashes '\' for compatibility with Amiga
    and UNIX file systems etc.

Unless you have a use-case that needs non-standard Zip member names, you
should leave this option well alone.

Unsurprizingly then, the default for this option is C<True>.

=head4 Bool zip64 => True|False

B<TODO> -- this option has not been implemented yet.

Specify the C<zip64> option on individual call to C<add> to override
this default.

=head2 method add($filename|@filenames [,options])

Used to add one or more a files to a Zip archive. The method expects one
mandatory parameter and zero or more optional parameters.

The first, mandatory, parameter contains the filename (or filenames) to be added to the zip file.
The method returns the number of files added.

To add a single file from the filesystem the first parameter must be coercable to
C<IO::Path>

    # Add a single file to the zip archive
    $zip.add("/tmp/fred");

Multiple files can be added in one step by passing C<add> an C<Iterable>,  like so

    my @files = 'file1.txt', 'file2.txt';
    $zip.add: @files;

or via the C<Seq> that C<File::Find> uses

    use File::Find;
    $zip.add: find(:dir<.>));

or via an C<IO::Glob>

    use IO::Glob;
    $zip.add: glob("*.c");

=head3 Options

=head4 name => String|Code

Override the B<name> field in the zip archive.

By default C<add> will use a normalized version of the filename that is passed
in the first parameter.
When the C<name> option is supplied, the value passed in the option will
be stored in the Zip archive, rather than the filename.

The C<name> option can either be a literal string or executable code.
For example, to change the filename to the literal string C<fred>

    $zip.add: "/somefile/fred.txt", :name<fred>;

alternatively you can supply a snippet of code to determine the filename.
For example, to remove all the path components from the filenames

    $zip.add: '/some/path/my.txt', :name( *.subst: rx[ ^ .+ '/'], '') ) ;

will mean the filename will be transformed from C</some/path/my.txt> to C<my.txt>
before being written to the zip file.

This option is particularly usefule when you have a list of filenames.
For example, to remove all the paths from the filenames returned from
C<File::Find> you can use this

    use File::Find;

    $zip.add: find(:dir<.>), :name( *.subst: rx[ ^ .+ '/'], '') ) ;


If the C<canonical-name> option is also C<True>, the value of the C<name> option
will be normalized to Unix format before being written to the Zip archive.

=head4 method => Zip-CM-Deflate|Zip-CM-Store

Used to set the compression algorithm used for this member. If C<method>
has not been specifed here or in C<new> it will default to
C<Zip-CM-Deflate>.

Valid values are

=item Zip-CM-Deflate
=item Zip-CM-Store

=head4 Bool stream => True|False

Write this member in streaming mode.

=head4 comment => String

Creates a comment for the member.

    my $zip = SimpleZip.new($archive, :comment<my comment>);

Note: this is different from the C<comment> option in the C<new> method.

=head4 canonical-name  => True|False

Controls how the I<name> field is written top the zip archive.

=head4 zip64 => True|False



=head2 method create($name, $payload [, options])

Create a zip entry using a string or a blob for the payload data.
Takes two mandatory parameters, namely the name of the zip entry to be written to the zipfile
and the payload data to be compressed.
 Also takes zero or more optional parameters.

To add a string/blob to a zip archive

    # Create a zip entry from a string
    $zip.create("file1", "payload data here");

    # Create a zip entry from a blob
    $zip.create("file2", Blob.new([2,4,6]));

Drop a filehandle into the zip archive

    my $handle = "some file".IO.open;
    $zip.create("file3", $handle);

C<create> also provides nother way to write the contents of a file into a zipfile.
The payload paramter must of of type IO for this to work.

    $zip.create("file4", "/a/real/filename".IO);

Behind the scenes C<create> will be used if Associative syntax is used

    $zip<file5> = "payload data";
    $zip<file6> = Blob.new([2,4,6]);
    $zip<file7> = $filehandle;
    $zip<file8> = "/a/real/filename".IO;

=head3 Options

Same options as C<add>.

=head2 method close

Does the following

=item1 Writes the zip file central directory to the output file

=item1 closes the file

=head1 Use of C<SimpleZip> in a Method Chain

It is possible to use this module in a I<method chain>. For example, you could
add all the files matched by C<File::Find> using the C<add> method

    use Archive::SimpleZip;
    use File::Find;

    my $zip = SimpleZip.new: "test.zip";

    $zip.add: find(:dir<.>));

    $zip.close;

Alternatively,instead of using the C<add> method
you can use this to achieve the same thing

    find(:dir<.>).$zip;

Here is a more complex example

    my $zip = SimpleZip: "my.zip";
    find(:dir<.>).grep( ! *.d).$zip.uc.sort.say ;
    $z.close();

this chain does the following

=item1 use C<find> to get a list of files
=item1 uses C<grep> to discard directories
=item1 add the remaining files to the zip file
=item1 converts the filenames to upper case
=item1 displays the uppercase filename

=head1 TODO

=item Zip64

=item Bzip2

Bzip2 suppport is written but disabled because C<Compress::Bzip2> isn't building
on Winows or MacOS.

=item Support for extra fields

=item Standard extra fields to store more accurate timestams.

=AUTHOR Paul Marquess <pmqs@cpan.org>
=end pod
