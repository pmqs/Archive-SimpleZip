#!perl6

use v6;
use lib 'lib';
use lib 't';

use Test;

plan 16;

use ZipTest;

if ! external-zip-works()
{
    skip-rest("Cannot find external zip/unzip or they do not work as expected.");
    exit;
}

use File::Temp;
use Archive::SimpleZip ;
use Archive::SimpleZip::Utils;

# Keep the test directory?
my $wipe = False;

my $base_dir_name = tempdir(:unlink($wipe));
ok $base_dir_name.IO.d, "tempdir { $base_dir_name } created";

ok chdir($base_dir_name), "chdir to { $base_dir_name } ok";

my $dir1 = 'dir1';
ok mkdir($dir1, 0o777), "created $dir1";

my $zipfile = "test.zip" ;
my $zipfile2 = 'test2.zip';
my $datafile = "$dir1/data123";
my $datafile1 = "data124";
my $datafile2 = "data125".IO;

my $empty-file = "empty";
spurt $empty-file, "";

subtest # empty zip file
{
    unlink $zipfile;

    nok $zipfile.IO.e, "$zipfile does not exists";

    my $zip = SimpleZip.new($zipfile, :stream);
    isa-ok $zip, SimpleZip;

    ok $zip.close(), "closed";

    ok $zipfile.IO.e, "$zipfile exists";

    is get-filenames-in-zip($zipfile), [], "filename OK";

}, 'empty zip file' ;

subtest # add
{
    unlink $zipfile;
    spurt $datafile, "some data" ;
    spurt $datafile1, "more data" ;
    my $text = "line 1\nline 2\nline 3";

    spurt $datafile2, $text ;


    ok  $datafile.IO.e, "$datafile does exists";
    nok $zipfile.IO.e, "$zipfile does not exists";

    my $zip = SimpleZip.new($zipfile, :stream, comment => 'file comment');
    isa-ok $zip, SimpleZip;

    ok $zip.add($datafile1.IO), "add file.IO";
    ok $zip.add($datafile.IO, :name<new>), "add file.IO but override name";
    ok $zip.add($datafile, :name<fred>, comment => 'member comment'), "add string filename ok";
    ok $zip.add($datafile2, :name</joe//bad>, :method(Zip-CM-Store), :stream, :!canonical-name), "add string filename, STORE";
    # ok $zip.add(Buf.new([2,4,6]), :name</jim/>, :stream), "add string, Stream";
    ok $zip.add($datafile2.open, :name<handle>), "Add filehandle";
    ok $zip.add($empty-file), "Add  empty-file file";
    ok $zip.add($dir1), "Add  Directory";
    ok $zip.close(), "closed";

    ok $zipfile.IO.e, "$zipfile exists";

    ok test-with-unzip($zipfile), "unzip likes the zip file";

    is comment-from-unzip($zipfile), "file comment", "File comment ok";
    is pipe-in-from-unzip($zipfile, 'new'), "some data", "member new ok";
    is pipe-in-from-unzip($zipfile, $datafile1), "more data", "member $datafile1 ok";
    is pipe-in-from-unzip($zipfile, "fred"), "some data", "member fred ok";
    is pipe-in-from-unzip($zipfile, "/joe//bad"), $text, "member /joe//bad ok";
    # is pipe-in-from-unzip($zipfile, "jim", :binary).decode, "\x2\x4\x6", "member jim ok";
    # is pipe-in-from-unzip($zipfile, "bz", :binary).decode, "str", "member bz ok";
    is pipe-in-from-unzip($zipfile, "handle"), $text, "member handle ok";
    is pipe-in-from-unzip($zipfile, $empty-file), "", "empty file ok";
    is pipe-in-from-unzip($zipfile, $dir1 ~ '/'), "", "directory ok";
    # is pipe-in-from-unzip($zipfile, $dir1), "", "directory ok";

}, 'add' ;

subtest # bzip2
{
    unlink $zipfile;
    spurt $datafile, "some data" ;

    ok  $datafile.IO.e, "$datafile does exists";
    nok $zipfile.IO.e, "$zipfile does not exists";

    my $zip = SimpleZip.new: $zipfile;
    isa-ok $zip, SimpleZip;

    ok $zip.add($datafile.IO, :method(Zip-CM-Bzip2), :stream), "add filename, Bzip2";
    ok $zip.close(), "closed";

    ok $zipfile.IO.e, "$zipfile exists";

    # ok test-with-unzip($zipfile), "unzip likes the zip file";

    is pipe-in-from-unzip($zipfile, $datafile), "some data", "member $datafile ok";

}, 'bzip2' ;

subtest # create
{
    unlink $zipfile;
    unlink $datafile2 ;

    my $text = "line 1\nline 2\nline 3";

    spurt $datafile2, $text ;

    ok  $datafile1.IO.e, "$datafile1 does exists";
    nok $zipfile.IO.e, "$zipfile does not exists";

    my $zip = SimpleZip.new($zipfile, :stream, comment => 'file comment');
    isa-ok $zip, SimpleZip;

    ok $zip.create('file1', $text);

    my Buf $b .= new([2,4,6]) ;

    ok $zip.create('file2', $b);
    ok $zip.create('file3', $datafile2.open);
    ok $zip.create('file4', $datafile2) ;


    ok $zip.close(), "closed";

    ok $zipfile.IO.e, "$zipfile exists";

    ok test-with-unzip($zipfile), "unzip likes the zip file";

    is pipe-in-from-unzip($zipfile, "file1"), $text, "member file1 ok";
    is pipe-in-from-unzip($zipfile, "file2"),  $b.decode('latin1'), "member file2 ok";
    is pipe-in-from-unzip($zipfile, "file3"), $text, "member file3 ok";
    is pipe-in-from-unzip($zipfile, "file4"), $text, "member file4 ok";


}, 'create' ;


subtest # associative
{
    unlink $zipfile;
    unlink $datafile ;

    ok ! $zipfile.IO.e, "$zipfile exists";

    my $text = "line 1\nline 2\nline 3";

    spurt $datafile2, $text ;

    ok  $datafile2.IO.e, "$datafile does exists";
    ok ! $zipfile.IO.e, "$zipfile does not exists";

    my $zip = SimpleZip.new($zipfile, :stream, comment => 'file comment');
    isa-ok $zip, SimpleZip;

    ok $zip{'file1'} = $text;

    my Buf $b .= new([2,4,6]) ;

    ok $zip<file2> = $b;
    ok $zip<file3> = $datafile2.open;
    ok $zip<file4> = $datafile2;


    ok $zip.close(), "closed";

    ok $zipfile.IO.e, "$zipfile exists";

    ok test-with-unzip($zipfile), "unzip likes the zip file";

    is pipe-in-from-unzip($zipfile, "file1"), $text, "member file1 ok";
    is pipe-in-from-unzip($zipfile, "file2"),  $b.decode('latin1'), "member file2 ok";
    is pipe-in-from-unzip($zipfile, "file3"), $text, "member file3 ok";
    is pipe-in-from-unzip($zipfile, "file4"), $text, "member file4 ok";


}, 'associative' ;

# subtest # add to blob
# {
#     unlink $zipfile;
#     spurt $datafile, "some data" ;
#     spurt $datafile1, "more data" ;
#     my $text = "line 1\nline 2\nline 3";

#     spurt $datafile2, $text ;

#     ok  $datafile.IO.e, "$datafile does exists";
#     nok $zipfile.IO.e, "$zipfile does not exists";

#     # Write zip to Blob

#     my Blob $data .= new();
#     my $zip2 = SimpleZip.new($data);
#     isa-ok $zip2, SimpleZip;
#     ok $zip2.create('fred', "abcde", :name<fred>), "add";
#     ok $zip2.close(), "closed";

#     my $file2 = "file2.zip".IO;
#     spurt $file2, $data, :bin;
#     ok $file2.e, "$file2 does exists";
#     ok $file2.s, "$file2 not empty";

#     diag "File size { $file2.s }\n";

#     ok test-with-unzip($file2), "unzip likes the zip file";

#     is pipe-in-from-unzip($file2, 'fred'), "abcde", "member fred ok";
# }, 'add to blob' ;

subtest # language encoding bit
{
    # Local Header for the  zip should look like this
    #
    # 0000 0004 50 4B 03 04 LOCAL HEADER #1       04034B50
    # 0004 0001 14          Extract Zip Spec      14 '2.0'
    # 0005 0001 00          Extract OS            00 'MS-DOS'
    # 0006 0002 00 08       General Purpose Flag  0800
    #                       [Bits 1-2]            0 'Normal Compression'
    #                       [Bit 11]              1 'Language Encoding'
    # 0008 0002 08 00       Compression Method    0008 'Deflated'
    # 000A 0004 0E 9A D3 50 Last Mod Time         50D39A0E 'Fri Jun 19 19:16:28 2020'
    # 000E 0004 DA 9C 56 2C CRC                   2C569CDA
    # 0012 0004 11 00 00 00 Compressed Length     00000011
    # 0016 0004 09 00 00 00 Uncompressed Length   00000009
    # 001A 0002 02 00       Filename Length       0002
    # 001C 0002 00 00       Extra Length          0000
    # 001E 0002 CE B1       Filename              'α'
    # 0020 0011 CA CD 2F 4A PAYLOAD               ../JUHI,I........
    #           55 48 49 2C
    #           49 04 00 00
    #           00 FF FF 03
    #           00

    unlink $zipfile;
    spurt $datafile, "some data" ;
    spurt $datafile1, "more data" ;

    ok  $datafile.IO.e, "$datafile does exists";
    nok $zipfile.IO.e, "$zipfile does not exists";

    my $zip = SimpleZip.new($zipfile);
    isa-ok $zip, SimpleZip;

    is $zip.add($datafile1.IO, :name("\c[GREEK SMALL LETTER ALPHA]")), 1, "add file";

    ok $zip.close(), "closed";

    with open $zipfile, :enc('latin1')
    {
        # Get general purpose flags
        .seek(0x07, SeekFromBeginning) ;
        my $got = .read: 1;

        ok $got +& 0x07 , "Language encoding bit set"
            or diag "Got " ~ Int($got);

        # filename
        .seek(0x12, SeekFromBeginning) ;
        $got = .read: 2;
        # diag "GOT " ~ $got.^name ;
        # diag "EXPECT " ~ string-to-binary("\c[GREEK SMALL LETTER ALPHA]").^name ;
        cmp-ok $got, 'cmp', string-to-binary("\c[GREEK SMALL LETTER ALPHA]"), "filename is ok"
            or run-zipdetails($zipfile);
        .close;
    }

}, "language encoding bit";

subtest # IO::Glob
{
    use IO::Glob;
    unlink $zipfile;

    my $dir2 = 'dir2';
    ok mkdir $dir2, 0o777;

    my $datafile = "$dir2/gdata123";
    my $datafile1 = "gdata124";
    my $datafile2 = "gdata125";

    spurt $datafile, "some data" ;
    spurt $datafile1, "more data" ;
    spurt $datafile2, "even more data" ;

    ok  $datafile.IO.e, "$datafile does exists";
    nok $zipfile.IO.e, "$zipfile does not exists";

    my $zip = SimpleZip.new($zipfile);
    isa-ok $zip, SimpleZip;

    is $zip.add(glob("gdata*")), 2, "add glob";

    ok $zip.close(), "closed";

    is get-filenames-in-zip($zipfile), glob("gdata*").dir, "filename OK";

}, "glob";


subtest # Seq
{
    use IO::Glob;
    unlink $zipfile;

    my $dir2 = 'dir2';
    ok mkdir $dir2, 0o777;

    my $datafile = "$dir2/gdata123";
    my $datafile1 = "gdata124";
    my $datafile2 = "gdata125";

    spurt $datafile, "some data" ;
    spurt $datafile1, "more data" ;
    spurt $datafile2, "even more data" ;

    ok  $datafile.IO.e, "$datafile does exists";
    nok $zipfile.IO.e, "$zipfile does not exists";

    my $zip = SimpleZip.new($zipfile);
    isa-ok $zip, SimpleZip;

    is $zip.add(glob("gdata*").dir), 2, "add seq";

    ok $zip.close(), "closed";

    is get-filenames-in-zip($zipfile), glob("gdata*").dir, "filename OK";

}, "seq";


subtest # Array
{
    # use IO::Glob;
    unlink $zipfile;

    my $dir2 = 'dir2';
    ok mkdir $dir2, 0o777;

    my $datafile = "$dir2/gdata123";
    my $datafile1 = "gdata124";
    my $datafile2 = "gdata125";

    spurt $datafile, "some data" ;
    spurt $datafile1, "more data" ;
    spurt $datafile2, "even more data" ;

    ok  $datafile.IO.e, "$datafile does exists";
    nok $zipfile.IO.e, "$zipfile does not exists";

    my $zip = SimpleZip.new($zipfile);
    isa-ok $zip, SimpleZip;

    my @array = ($datafile1.IO, $datafile2.IO);
    is $zip.add(@array), 2, "add array";

    ok $zip.close(), "closed";

    is get-filenames-in-zip($zipfile), @array, "filename OK";

}, "array";

subtest # List
{
    # use IO::Glob;
    unlink $zipfile;

    my $dir2 = 'dir2';
    ok mkdir $dir2, 0o777;

    my $datafile = "$dir2/gdata123";
    my $datafile1 = "gdata124";
    my $datafile2 = "gdata125";

    spurt $datafile, "some data" ;
    spurt $datafile1, "more data" ;
    spurt $datafile2, "even more data" ;

    ok  $datafile.IO.e, "$datafile does exists";
    nok $zipfile.IO.e, "$zipfile does not exists";

    my $zip = SimpleZip.new($zipfile);
    isa-ok $zip, SimpleZip;

    my $list = ($datafile1.IO, $datafile2.IO);
    is $zip.add($list), 2, "add list";

    ok $zip.close(), "closed";

    is get-filenames-in-zip($zipfile), $list, "filename OK";

}, "list";

subtest # CALL-ME
{
    use IO::Glob;

    my $dir3 = 'dir3';
    ok mkdir $dir3, 0o777;

    my @data-files ;
    for 0 .. 5 -> $f
    {
        my $filename = "$dir3/data$f";
        @data-files.push: $filename;
        spurt $filename, "some data in $filename";
        ok  $filename.IO.e, "$datafile does exists";
    }

    my $zipfile = "call-me.zip";

    {
        # IO

        nok $zipfile.IO.e, "$zipfile does not exists";

        my $zip = SimpleZip.new($zipfile);
        isa-ok $zip, SimpleZip;

        $zip(@data-files[0]);

        @data-files[1].$zip;

        $zip.close();

        is get-filenames-in-zip($zipfile), @data-files[0..1], "filename OK";
        unlink $zipfile;
    }

    {
        # List
        nok $zipfile.IO.e, "$zipfile does not exists";

        my $zip = SimpleZip.new($zipfile);
        isa-ok $zip, SimpleZip;

        my $l1 = @data-files[0..2];
        my $l2 = @data-files[3..5];

        isa-ok $l1, List;
        isa-ok $l2, List;

        $zip($l1);

        $l2.$zip;

        $zip.close();

        is get-filenames-in-zip($zipfile), @data-files[0 .. 5], "filename OK";
        unlink $zipfile;
    }

    {
        # Seq
        nok $zipfile.IO.e, "$zipfile does not exists";

        my $zip = SimpleZip.new($zipfile);
        isa-ok $zip, SimpleZip;

        my $l1 = @data-files[0..2].Seq;
        my $l2 = @data-files[3..5].Seq;

        isa-ok $l1, Seq;
        isa-ok $l2, Seq;

        $zip($l1);

        $l2.$zip;

        $zip.close();

        is get-filenames-in-zip($zipfile), @data-files[0 .. 5], "filename OK";
        unlink $zipfile;
    }

    {
        # IO::Glob

        nok $zipfile.IO.e, "$zipfile does not exists";

        my $zip = SimpleZip.new($zipfile);
        isa-ok $zip, SimpleZip;

        my $g1 = glob("$dir3/*0", :spec(IO::Spec::Unix));
        my $g2 = glob("$dir3/*1", :spec(IO::Spec::Unix));

        isa-ok $g1, IO::Glob;
        isa-ok $g2, IO::Glob;

        $zip($g1);

        $g2.$zip;

        $zip.close();

        is get-filenames-in-zip($zipfile), @data-files[0 .. 1], "filename OK";
        unlink $zipfile;

    }

}, "CALL-ME";

subtest # add/create with algorithmic name
{

    unlink $zipfile;
    spurt $datafile, "some data" ;
    spurt $datafile1, "more data" ;
    my $text = "line 1\nline 2\nline 3";

    spurt $datafile2, $text ;

    ok  $datafile.IO.e, "$datafile does exists";
    nok $zipfile.IO.e, "$zipfile does not exists";

    my $zip = SimpleZip.new: $zipfile ;
    isa-ok $zip, SimpleZip;

    ok $zip.add($datafile1, :name( *.subst: /^/, "abc-" )), "add file";

    ok $zip.create("fred", "some data", :name( *.subst: /^/, 'xxx-' )), "created ok" ;
    ok $zip.mkdir("joe", :name( *.subst: /^/, 'yyy-' )), "mkdir ok" ;

    ok $zip.close();

    is get-filenames-in-zip($zipfile), ["abc-$datafile1", "xxx-fred", "yyy-joe/"], "filenames changed OK" ;


}, 'add/create with algorithmic name' ;

subtest # file does not exist
{
    # Add file that doesn't exist
    unlink $zipfile;

    nok $zipfile.IO.e, "$zipfile does not exists";

    my $zip = SimpleZip.new($zipfile);
    isa-ok $zip, SimpleZip;

    throws-like($zip.add("file_does_not_exist".IO), X::AdHoc, message => rx:s/No such file or directory/) ;
}, "file does not exist" ;

done-testing();
