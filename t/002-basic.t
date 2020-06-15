#!perl6

use v6;
use lib 'lib';
use lib 't';

use Test;

plan 11;

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
my $datafile = "$dir1/data123";
my $datafile1 = "data124";
my $datafile2 = "data125".IO;

subtest
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

    ok $zip.add($datafile1.IO), "add file";
    ok $zip.add($datafile.IO, :name<new>), "add file but override name";
    ok $zip.add("abcde", :name<fred>, comment => 'member comment'), "add string ok";
    ok $zip.add("def", :name</joe//bad>, :method(Zip-CM-Store), :stream, :!canonical-name), "add string, STORE";
    ok $zip.add(Buf.new([2,4,6]), :name</jim/>, :stream), "add string, Stream";
    ok $zip.add($datafile2.open, :name<handle>), "Add filehandle";
    ok $zip.close(), "closed";

    ok $zipfile.IO.e, "$zipfile exists";

    ok test-with-unzip($zipfile), "unzip likes the zip file";

    is comment-from-unzip($zipfile), "file comment", "File comment ok";
    is pipe-in-from-unzip($zipfile, 'new'), "some data", "member new ok";
    is pipe-in-from-unzip($zipfile, $datafile1), "more data", "member $datafile1 ok";
    is pipe-in-from-unzip($zipfile, "fred"), "abcde", "member fred ok";
    is pipe-in-from-unzip($zipfile, "/joe//bad"), "def", "member /joe//bad ok";
    is pipe-in-from-unzip($zipfile, "jim", :binary).decode, "\x2\x4\x6", "member jim ok";
    # is pipe-in-from-unzip($zipfile, "bz", :binary).decode, "str", "member bz ok";
    is pipe-in-from-unzip($zipfile, "handle"), $text, "member handle ok";

}, 'add' ;

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
#     ok $zip2.add("abcde", :name<fred>), "add";
#     ok $zip2.close(), "closed";

#     my $file2 = "file2.zip".IO;
#     spurt $file2, $data, :bin;
#     ok $file2.e, "$file2 does exists";
#     ok $file2.s, "$file2 not empty";

#     diag "File size { $file2.s }\n";

#     ok test-with-unzip($file2), "unzip likes the zip file";

#     is pipe-in-from-unzip($file2, 'fred'), "abcde", "member fred ok";
# }, 'add to blob' ;

subtest
{
    unlink $zipfile;
    spurt $datafile, "some data" ;
    spurt $datafile1, "more data" ;

    ok  $datafile.IO.e, "$datafile does exists";
    nok $zipfile.IO.e, "$zipfile does not exists";

    my $zip = SimpleZip.new($zipfile);
    isa-ok $zip, SimpleZip;

    is $zip.add($datafile1.IO, :name("\c[GREEK SMALL LETTER ALPHA]")), 1, "add file";

    ok $zip.close(), "closed";

    is get-filenames-in-zip($zipfile), "\c[GREEK SMALL LETTER ALPHA]", "filename OK";

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

subtest
{
    # Add file that doesn't exist
    unlink $zipfile;

    nok $zipfile.IO.e, "$zipfile does not exists";

    my $zip = SimpleZip.new($zipfile);
    isa-ok $zip, SimpleZip;

    throws-like($zip.add("file_does_not_exist".IO), X::AdHoc, message => rx:s/No such file or directory/) ;
}, "file does not exist" ;

done-testing();
